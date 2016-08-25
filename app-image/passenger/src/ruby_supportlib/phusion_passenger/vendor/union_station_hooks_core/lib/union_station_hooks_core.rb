#  Union Station - https://www.unionstationapp.com/
#  Copyright (c) 2015 Phusion Holding B.V.
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

if defined?(UnionStationHooks::VERSION_STRING)
  if UnionStationHooks.initialized?
    raise 'Attempted to load union_station_hooks_core even though an ' \
      'alternative version was already loaded and initialized'
  end
  if UnionStationHooks.vendored?
    # Passenger loaded its vendored Union Station hooks code, but the
    # application has also included 'union_station_hooks_*' in its Gemfile. We
    # want the version in the Gemfile to take precedence, so we unload the old
    # version. At this point, the Union Station hooks aren't installed yet, so
    # removing the module is enough to unload the old version.
    #
    # See also hacking/Vendoring.md
    config_from_vendored_ush = UnionStationHooks.config
    initializers_from_vendored_ush = UnionStationHooks.initializers
    Object.send(:remove_const, :UnionStationHooks)
  end
end

# The UnionStationHooks module is the entry point to the
# `union_station_hooks_core` gem's public API. Note that this API is only
# available since Passenger 5.0.20!
#
# **_Not familiar with `union_station_hooks_core`? Please read the
# [README](https://github.com/phusion/union_station_hooks_core)
# for an introduction._**
#
# ## Places of interest
#
# You will probably be most interested in these:
#
#  * {UnionStationHooks.initialize!}
#  * {UnionStationHooks.begin_rack_request} and
#    {UnionStationHooks.end_rack_request}
#  * {UnionStationHooks::RequestReporter}
#  * {UnionStationHooks.log_exception}
#
# ## Rack example
#
# Here is a small example showing to use `union_station_hooks_core` with a
# bare Rack application. There are three main things you see in this example:
#
#  1. The `union_station_hooks_*` gems are initialized.
#  2. Obtaining a RequestReporter object, which is the main object that you
#     will be using as an application developer to log information to Union
#     Station.
#  3. Using the RequestReporter object by calling methods on it.
#
# Example code follows:
#
#     # (1) Initialize all `union_station_hooks_*` gems.
#     UnionStationHooks.initialize!
#
#     # Define application object.
#     app = lambda do |env|
#       body, rendering_time = process_this_request(env)
#
#       # (2) You can obtain a RequestReporter object as follows. With that
#       # object, you can log to Union Station information about the current
#       # request.
#       reporter = env['union_station_hooks']
#       # -OR- (if you don't have access to the Rack env):
#       reporter = Thread.current[:union_station_hooks]
#
#       # The reporter object may be nil because of various error conditions,
#       # so you must check for it.
#       if reporter
#         # (3) For example you can log the amount of time it took to render
#         # the view.
#         reporter.log_total_view_rendering_time(rendering_time)
#       end
#
#       [200, { "Content-Type" => "text/plain" }, body]
#     end
#
#     # Tell the application server to run this application object.
#     run app
module UnionStationHooks
  # The path to the `union_station_hooks_core` Ruby library directory.
  #
  # @private
  LIBROOT = File.expand_path(File.dirname(__FILE__))

  # The path to the `union_station_hooks_core` gem root directory.
  #
  # @private
  ROOT = File.dirname(LIBROOT)

  class << self
    # This error is raised by {UnionStationHooks.initialize!} if a required
    # {UnionStationHooks.config configuration option} is missing.
    class ConfigurationError < StandardError
    end

    # @private
    @@config = {}
    # @private
    @@context = nil
    # @private
    @@initializers = []
    # @private
    @@initialized = false
    # @private
    @@app_group_name = nil
    # @private
    @@key = nil
    # @private
    @@vendored = false

    # Initializes the Union Station hooks. If there are any other
    # `union_station_hooks_*` gems loaded, then they are initialized too.
    #
    # Applications must call this during startup. Hooks aren't actually
    # installed until this method is called, so until you call this you cannot
    # use the public APIs of any `union_station_hooks_*` gems (besides trivial
    # things such as {UnionStationHooks.initialized?}).
    #
    # A good place to call this is in the Rackup file `config.ru`. Or, if your
    # application is a Rails app, then you should create an initializer file
    # `config/initializers/union_station.rb` in which you call this.
    #
    # If this method successfully initializes, then it returns true.
    #
    # Calling this method may or may not actually initialize the hooks. If
    # this gem determines that initialization is not desired, then this method
    # won't do anything and will return `false`. See
    # {UnionStationHooks#should_initialize?}.
    #
    # Initialization takes place according to parameters set in the
    # {UnionStationHooks.config configuration hash}. If a required
    # configuration option is missing, then this method will raise a
    # {ConfigurationError}.
    #
    # Initializing twice is a no-op. It only causes this method to return true.
    #
    # @raise [ConfigurationError] A required configuration option is missing.
    # @return [Boolean] Whether initialization was successful.
    def initialize!
      return false if !should_initialize?
      return true if initialized?

      finalize_and_validate_config
      require_lib('api')
      create_context
      install_postfork_hook
      install_event_pre_hook
      initialize_other_union_station_hooks_gems
      finalize_install

      true
    end

    # Returns whether the Union Station hooks are initialized.
    def initialized?
      @@initialized
    end

    # Returns whether the Union Station hooks should be initialized. If this
    # method returns false, then {UnionStationHooks.initialize!} doesn't do
    # anything.
    #
    # At present, this method only returns true when the app is running inside
    # Passenger. This may change if and when in the future Union Station
    # supports application servers besides Passenger.
    def should_initialize?
      if defined?(PhusionPassenger)
        PhusionPassenger::App.options['analytics']
      else
        true
      end
    end

    # Returns whether this `union_station_hooks_core` gem is bundled with
    # Passenger (as opposed to a standalone gem added to the Gemfile).
    # See the README and the file `hacking/Vendoring.md` for information
    # about how Passenger bundles `union_station_hooks_*` gems.
    #
    # @private
    def vendored?
      @@vendored
    end

    # @private
    def vendored=(val)
      @@vendored = val
    end

    # @private
    def require_lib(name)
      require("#{LIBROOT}/union_station_hooks_core/#{name}")
    end

    # Returns the configuration hash. This configuration is used by all
    # `union_station_hooks_*` gems. You are supposed to set this hash
    # before calling {UnionStationHooks.initialize!}.
    #
    # At present, none of the `union_station_hooks_*` gems require
    # additional configuration. All necessary configuration is pulled from
    # Passenger. This may change if and when Union Station in the future
    # supports application servers besides Passenger.
    #
    # This hash is supposed to only contain symbol keys, not string keys.
    # When {UnionStationHooks.initialize!} is called, that method will
    # convert all string keys to symbol keys before doing anything else
    # with the config hash, so assigning string keys works even though
    # we don't recommend it. Furthermore, the config hash is frozen after
    # initialization.
    #
    # @return [Hash]
    def config
      @@config
    end

    # The singleton {Context} object, created during initialization.
    # All the `union_station_hooks_*` gem internals make use of this context
    # object.
    #
    # @private
    def context
      @@context
    end

    # An array of objects on which `#initialize!` will be called when
    # {UnionStationHooks.initialize!} is called. Other `union_station_hooks_*`
    # gems register themselves in this list when they are loaded, so that
    # a call to {UnionStationHooks.initialize!} will initialize them too.
    #
    # @private
    def initializers
      @@initializers
    end

    # @private
    def app_group_name
      @@app_group_name
    end

    # The currently active Union Station key. This is pulled from the
    # {UnionStationHooks.config configuration}.
    #
    # @private
    def key
      @@key
    end

    # @private
    def call_event_pre_hook(_event)
      raise 'This method may only be called after ' \
        'UnionStationHooks.initialize! is called'
    end

    # Called by Passenger after loading the application, to check whether or
    # not the application developer forgot to call
    # {UnionStationHooks.initialize!}. If so, it logs the problem and
    # initializes now.
    #
    # @private
    def check_initialized
      return if !should_initialize? || initialized?
      return if !config.fetch(:check_initialized, true)

      if defined?(::Rails)
        message = 'The Union Station hooks are not initialized. Please ensure ' \
          'that you have an initializer file ' \
          '`config/initializers/union_station.rb` in which you call ' \
          "this:\n\n" \
          "  if defined?(UnionStationHooks)\n" \
          "    UnionStationHooks.initialize!\n" \
          "  end"
      else
        message = 'The Union Station hooks are not initialized. Please ensure ' \
          'that the following code is called during application ' \
          "startup:\n\n" \
          "  if defined?(UnionStationHooks)\n" \
          "    UnionStationHooks.initialize!\n" \
          "  end"
      end

      STDERR.puts(" *** WARNING: #{message}")
      @@config[:initialize_from_check] = true
      initialize!
      report_internal_information('HOOKS_NOT_INITIALIZED', message)
    end

    def now
      # When `initialize!` is called, the definition in
      # `api.rb` will override this implementation.
      nil
    end

    def begin_rack_request(_rack_env)
      # When `initialize!` is called, the definition in
      # `api.rb` will override this implementation.
      nil
    end

    def end_rack_request(_rack_env,
        _uncaught_exception_raised_during_request = false)
      # When `initialize!` is called, the definition in
      # `api.rb` will override this implementation.
      nil
    end

    def log_exception(_exception)
      # When `initialize!` is called, the definition in
      # `api.rb` will override this implementation.
      nil
    end

    def get_delta_monotonic
      # When `initialize!` is called, the definition in
      # `api.rb` will override this implementation.
      nil
    end

  private

    def finalize_and_validate_config
      final_config = {}

      if defined?(PhusionPassenger)
        import_into_final_config(final_config, PhusionPassenger::App.options)
      end
      import_into_final_config(final_config, config)

      validate_final_config(final_config)

      @@config = final_config
    end

    def import_into_final_config(dest, source)
      source.each_pair do |key, val|
        dest[key.to_sym] = val
      end
    end

    def validate_final_config(config)
      require_non_empty_config_key(config, :union_station_key)
      require_non_empty_config_key(config, :app_group_name)
      require_non_empty_config_key(config, :ust_router_address)
      require_non_empty_config_key(config, :ust_router_password)
    end

    def require_non_empty_config_key(config, key)
      if config[key].nil? || config[key].empty?
        raise ArgumentError,
          "Union Station hooks configuration option required: #{key}"
      end
    end

    def require_simple_json
      if defined?(PhusionPassenger)
        begin
          PhusionPassenger.require_passenger_lib('utils/json')
          UnionStationHooks.const_set(:SimpleJSON, PhusionPassenger::Utils)
        rescue LoadError
        end
      end
      if !defined?(UnionStationHooks::SimpleJSON)
        require_lib('simple_json')
      end
    end

    def report_internal_information(type, message, data = nil)
      data ||= {}
      data[:app_type] ||= :ruby
      if defined?(::Rails)
        data[:framework_type] = :rails
      end

      if defined?(PhusionPassenger)
        data[:app_server] = {
          :id => :passenger,
          :version => PhusionPassenger::VERSION_STRING
        }
      end

      body = SimpleJSON::JSON.generate(
        :type => type,
        :message => message,
        :data => data
      )

      transaction = context.new_transaction(app_group_name,
        :internal_information, key)
      begin
        transaction.message(body)
      ensure
        transaction.close
      end
    end
  end
end

UnionStationHooks.require_lib('version')

if config_from_vendored_ush
  UnionStationHooks.config.replace(config_from_vendored_ush)
  UnionStationHooks.initializers.replace(initializers_from_vendored_ush)
end
