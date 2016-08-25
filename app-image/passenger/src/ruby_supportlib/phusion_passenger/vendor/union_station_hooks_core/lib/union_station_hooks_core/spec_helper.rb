#  Union Station - https://www.unionstationapp.com/
#  Copyright (c) 2010-2015 Phusion Holding B.V.
#
#  "Union Station" and "Passenger" are trademarks of Phusion Holding B.V.
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.

require 'fileutils'
require 'net/http'
require 'uri'

module UnionStationHooks
  # Contains helper methods for use in unit tests across all the
  # `union_station_hooks_*` gems.
  #
  # @private
  module SpecHelper
    extend self # Make methods available as class methods.

    def self.included(klass)
      # When included into another class, make sure that Utils
      # methods are made private.
      public_instance_methods(false).each do |method_name|
        klass.send(:private, method_name)
      end
    end

    # To be called during initialization of the test suite.
    def initialize!
      load_passenger
      initialize_ush_api
      initialize_debugging
      undo_bundler
    end

    # Lookup the `passenger-config` command, either by respecting the
    # `PASSENGER_CONFIG` environment variable, or by looking it up in `PATH`.
    # If the command cannot be found, the current process aborts with an
    # error message.
    def find_passenger_config
      passenger_config = ENV['PASSENGER_CONFIG']
      if passenger_config.nil? || passenger_config.empty?
        passenger_config = find_passenger_config_vendor ||
          find_passenger_config_in_path
      end
      if passenger_config.nil? || passenger_config.empty?
        abort 'ERROR: The unit tests are to be run against a specific ' \
          'Passenger version. However, the \'passenger-config\' command is ' \
          'not found. Please install Passenger, or (if you are sure ' \
          'Passenger is installed) set the PASSENGER_CONFIG environment ' \
          'variable to the \'passenger-config\' command.'
      end
      passenger_config
    end

    # Looks for the passenger-config command in PATH, returning nil
    # if not found.
    def find_passenger_config_in_path
      ENV['PATH'].split(':').each do |path|
        if File.exist?("#{path}/passenger-config")
          return "#{path}/passenger-config"
        end
      end
    end

    # Checks whether this union_station_hooks installation is a copy that
    # is vendored into Passenger, and if so, returns the full path to the
    # containing Passenger's passenger-config command.
    def find_passenger_config_vendor
      path = "#{UnionStationHooks::ROOT}/../../../../../bin/passenger-config"
      if File.exist?(path)
        File.expand_path(path)
      else
        nil
      end
    end

    # Uses `find_passenger_config` to lookup a Passenger installation, and
    # loads the Passenger Ruby support library associated with that
    # installation. All the constants defined in the Passenger Ruby support
    # library are loaded. In addition, checks whether the Passenger agent
    # executable is installed. If not, the current process aborts with an
    # error message.
    def load_passenger
      passenger_config = find_passenger_config
      puts "Using Passenger installation at: #{passenger_config}"
      passenger_ruby_libdir = `#{passenger_config} about ruby-libdir`.strip
      require("#{passenger_ruby_libdir}/phusion_passenger")
      PhusionPassenger.locate_directories
      PhusionPassenger.require_passenger_lib 'constants'
      puts "Loaded Passenger version #{PhusionPassenger::VERSION_STRING}"

      agent = PhusionPassenger.find_support_binary(PhusionPassenger::AGENT_EXE)
      if agent.nil?
        abort "ERROR: The Passenger agent isn't installed. Please ensure " \
          "that it is installed, e.g. using:\n\n" \
          "  #{passenger_config} install-agent\n\n"
      end
    end

    def initialize_ush_api
      UnionStationHooks.require_lib('api')
      UnionStationHooks.instance_variable_set(:@mono_mutex, Mutex.new)
      UnionStationHooks.instance_variable_set(:@delta_monotonic, 0)
    end

    def initialize_debugging
      @@debug = !ENV['DEBUG'].to_s.empty?
      if @@debug
        UnionStationHooks.require_lib('log')
        UnionStationHooks::Log.debugging = true
      end
    end

    # Unit tests must undo the Bundler environment so that the gem's
    # own Gemfile doesn't affect subprocesses that may have their
    # own Gemfile.
    def undo_bundler
      clean_env = nil
      Bundler.with_clean_env do
        clean_env = ENV.to_hash
      end
      ENV.replace(clean_env)
    end

    # Checks whether `initialize_debugging` enabled debugging mode.
    def debug?
      @@debug
    end

    # Writes the given content to the file at the given path. If or or more
    # parent directories don't exist, then they are created.
    def write_file(path, content)
      dir = File.dirname(path)
      if !File.exist?(dir)
        FileUtils.mkdir_p(dir)
      end
      File.open(path, 'wb') do |f|
        f.write(content)
      end
    end

    def get_response(path)
      uri = URI.parse("#{root_url}#{path}")
      Net::HTTP.get_response(uri)
    end

    def get(path)
      response = get_response(path)
      return_200_response_body(path, response)
    end

    def return_200_response_body(path, response)
      if response.code == '200'
        response.body
      else
        raise "HTTP request to #{path} failed.\n" \
          "Code: #{response.code}\n" \
          "Body:\n" \
          "#{response.body}"
      end
    end

    # Opens a debug shell. By default, the debug shell is opened in the current
    # working directory. If the current module has the `prepare_debug_shell`
    # method, that method is called before opening the debug shell. The method
    # could, for example, change the working directory.
    #
    # This method does *not* raise an exception if the debug shell exits with
    # an error.
    def debug_shell
      puts '------ Opening debug shell -----'
      @orig_dir = Dir.pwd
      begin
        if respond_to?(:prepare_debug_shell)
          prepare_debug_shell
        end
        system('bash')
      ensure
        Dir.chdir(@orig_dir)
      end
      puts '------ Exiting debug shell -----'
    end

    # Returns the path of a specific UstRouter dump file.
    # Requires that `@dump_dir` is set.
    def dump_file_path(category = 'requests')
      raise '@dump_dir variable required' if !@dump_dir
      "#{@dump_dir}/#{category}"
    end

    # Reads the contents of a specific UstRouter dump file.
    # Requires that `@dump_dir` is set.
    #
    # @raise SystemError Something went wrong during reading.
    def read_dump_file(category = 'requests')
      File.read(dump_file_path(category))
    end

    # Waits until the dump file exists. Raises an error if
    # this doesn't become true within the default {#eventually}
    # timeout.
    def wait_for_dump_file_existance(category = 'requests')
      eventually do
        File.exist?(dump_file_path(category))
      end
    end

    # Assert that the dump file eventually exists and that its contents
    # eventually match the given regex.
    def eventually_expect_dump_file_to_match(regex, category = 'requests')
      wait_for_dump_file_existance(category)
      eventually do
        read_dump_file(category) =~ regex
      end
    end

    # Assert that the dump file (if it ever exists) its contents will never match
    # the given regex.
    def never_expect_dump_file_to_match(regex, category = 'requests')
      should_never_happen do
        File.exist?(dump_file_path(category)) &&
          read_dump_file(category) =~ regex
      end
    end

    # Makes `UnionStationHooks::Log.warn` not print anything.
    def silence_warnings
      UnionStationHooks::Log.warn_callback = lambda { |_message| }
    end

    # Asserts that something should eventually happen. This is done by checking
    # that the given block eventually returns true. The block is called
    # once every `check_interval` msec. If the block does not return true
    # within `deadline_duration` secs, then an exception is raised.
    def eventually(deadline_duration = 3, check_interval = 0.05)
      deadline = Time.now + deadline_duration
      while Time.now < deadline
        if yield
          return
        else
          sleep(check_interval)
        end
      end
      raise 'Time limit exceeded'
    end

    # Asserts that something should never happen. This is done by checking that
    # the given block never returns true. The block is called once every
    # `check_interval` msec, until `deadline_duration` seconds have passed.
    # If the block ever returns true, then an exception is raised.
    def should_never_happen(deadline_duration = 0.5, check_interval = 0.05)
      deadline = Time.now + deadline_duration
      while Time.now < deadline
        if yield
          raise "That which shouldn't happen happened anyway"
        else
          sleep(check_interval)
        end
      end
    end
  end
end
