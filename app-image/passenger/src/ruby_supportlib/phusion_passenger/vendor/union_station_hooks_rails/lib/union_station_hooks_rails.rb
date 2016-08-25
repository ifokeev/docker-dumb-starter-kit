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

# Important notes:
#
# - We can't define a Railtie in this gem because union_station_hooks_rails
#   may be loaded from Passenger, before Rails is loaded.
# - Make sure that you do not install any actual hooks until `initialize!`
#   is called. Otherwise, union_station_hooks_core won't be able to properly
#   upgrade the Union Station hook code vendored in Passenger.
#   See https://github.com/phusion/union_station_hooks/hacking/Vendoring.md
#   for more information.

if defined?(UnionStationHooksRails::VERSION_STRING)
  if UnionStationHooksRails.initialized?
    raise 'Attempted to load union_station_hooks_core even though an ' \
      'alternative version was already loaded and initialized'
  end
  if UnionStationHooksRails.vendored?
    # Passenger loaded its vendored Union Station hooks code, but the
    # application has also included 'union_station_hooks_*' in its Gemfile. We
    # want the version in the Gemfile to take precedence, so we unload the old
    # version. At this point, the Union Station hooks aren't installed yet, so
    # removing the module is enough to unload the old version.
    #
    # See also:
    # https://github.com/phusion/union_station_hooks/blob/master/hacking/Vendoring.md
    if defined?(UnionStationHooks)
      UnionStationHooks.initializers.delete(UnionStationHooksRails)
    end
    Object.send(:remove_const, :UnionStationHooksRails)
  end
end

module UnionStationHooksRails
  # The path to the `union_station_hooks_rails` Ruby library directory.
  #
  # @private
  LIBROOT = File.expand_path(File.dirname(__FILE__))

  # The path to the `union_station_hooks_rails` gem root directory.
  #
  # @private
  ROOT = File.dirname(LIBROOT)

  class << self
    # @private
    @@initialized = false
    # @private
    @@vendored = false

    # Initializes `union_station_hooks_rails`. This method is automatically
    # called by `UnionStationHooks.initialized!` because we registered
    # ourselves in `UnionStationHooks.initializers`. The application does
    # not need to call this.
    #
    # If this method successfully initializes, then it returns true.
    #
    # Calling this method may or may not actually initialize
    # `union_station_hooks_rails`. If this gem determines that initialization
    # is not desired, then this method won't do anything and will return
    # `false`. See {UnionStationHooksRails#should_initialize?}.
    #
    # Initializing twice is a no-op. It only causes this method to return true.
    #
    # @private
    # @return [Boolean] Whether initialization was successful.
    def initialize!
      return false if !should_initialize?
      return true if initialized?

      begin
        require_lib('initialize')
        require_lib('active_record_subscriber')
        require_lib('exception_logger')
        if defined?(ActionView)
          require_lib('action_view_subscriber')
        end
        if defined?(ActiveSupport::Cache::Store)
          require_lib('active_support_cache_subscriber')
        end
        if defined?(ActionController::Base)
          require_lib('action_controller_extension')
        end
        if defined?(ActiveSupport::Benchmarkable)
          require_lib('active_support_benchmarkable_extension')
        end
      rescue => e
        if UnionStationHooks.config[:initialize_from_check]
          # The union_station_hooks_core gem already reported the error
          # to Union Station.
          STDERR.puts(' *** WARNING: an error occurred while initializing ' \
            'the Union Station Rails hooks. This is because you did not ' \
            'initialize the Union Station hooks from an initializer file. ' \
            'Please create an initializer file ' \
            '`config/initializers/union_station.rb` in which you call ' \
            "this:\n\n" \
            "  if defined?(UnionStationHooks)\n" \
            "    UnionStationHooks.initialize!\n" \
            "  end\n\n" \
            "The error is as follows:\n" \
            "#{e} (#{e.class})\n    " +
            e.backtrace.join("\n    "))
        else
          raise e
        end
      end

      @@initialized = true

      true
    end

    # Returns whether the Union Station hooks are initialized.
    def initialized?
      @@initialized
    end

    # Returns whether the Union Station hooks should be initialized. If this
    # method returns false, then {UnionStationHooksRails.initialize!} doesn't
    # do anything.
    #
    # This method only returns true if ActiveSupport >= 3 is currently loaded.
    def should_initialize?
      if defined?(::ActiveSupport) && !defined?(::ActiveSupport::VERSION)
        require 'active_support/version'
      end
      defined?(::ActiveSupport) && ::ActiveSupport::VERSION::MAJOR >= 3
    end

    # Returns whether this `union_station_hooks_rails` gem is bundled with
    # Passenger (as opposed to a standalone gem added to the Gemfile).
    # See the README and the file `hacking/Vendoring.md` in the
    # `union_station_hooks_core` gem for information about how Passenger
    # bundles `union_station_hooks_*` gems.
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
      require("#{LIBROOT}/union_station_hooks_rails/#{name}")
    end

    # @private
    def require_and_check_union_station_hooks_core
      if !defined?(UnionStationHooks::VERSION_STRING)
        require 'union_station_hooks_core'
      end

      # If you update the dependency version here, also update
      # the version in the gemspec and in the Gemfile.
      compatible = UnionStationHooks::MAJOR_VERSION == 2 &&
        ush_core_minor_and_tiny_version_compatible?
      if !compatible
        raise "This version of the union_station_hooks_rails gem " \
          "(#{VERSION_STRING}) is only compatible with the " \
          "union_station_hooks_core gem 2.x.x, starting from v2.0.3. " \
          "However, you have loaded union_station_hooks_core #{UnionStationHooks::VERSION_STRING}"
      end
    end

    # @private
    def ush_core_minor_and_tiny_version_compatible?
      UnionStationHooks::MINOR_VERSION >= 1 ||
        UnionStationHooks::TINY_VERSION >= 4
    end
  end
end

UnionStationHooksRails.require_lib('version')
UnionStationHooksRails.require_and_check_union_station_hooks_core
UnionStationHooks.initializers << UnionStationHooksRails
