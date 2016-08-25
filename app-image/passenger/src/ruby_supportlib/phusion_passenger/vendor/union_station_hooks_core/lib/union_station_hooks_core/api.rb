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

UnionStationHooks.require_lib 'utils'
UnionStationHooks.require_lib 'time_point'
UnionStationHooks.require_lib 'request_reporter'

module UnionStationHooks
  class << self
    # @note You do not have to call this! Passenger automatically calls
    #   this for you! Just obtain the RequestReporter object that has been made
    #   available for you.
    #
    # Indicates that a Rack request has begun. Given a Rack environment hash,
    # this method returns {RequestReporter} object, which you can use for
    # logging Union Station information about this request. This method should
    # be called as early as possible during a request, before any processing
    # has begun. Only after calling this method will it be possible to log
    # request-specific information to Union Station.
    #
    # The {RequestReporter} object that this method creates is also made
    # available through the `union_station_hooks` key in the Rack environment
    # hash, as well as the `:union_station_hooks` key in the current thread's
    # object:
    #
    #     env['union_station_hooks']
    #     # => RequestReporter object or nil
    #
    #     Thread.current[:union_station_hooks]
    #     # => RequestReporter object or nil
    #
    # If this method was already called on this Rack request, then this method
    # does nothing and merely returns the previously created {RequestReporter}.
    #
    # See {RequestReporter} to learn what kind of information you can log to
    # Union Station about Rack requests.
    #
    # @return [RequestReporter, nil] A {RequestReporter} object, or nil or
    #   because of certain error conditions. See the RequestReporter class
    #   description for when this may be nil.
    def begin_rack_request(rack_env)
      reporter = rack_env['union_station_hooks']
      return reporter if reporter

      # PASSENGER_TXN_ID may be nil here even if Union Station support is
      # enabled. For example, if the user tried to access the application
      # process directly through its private HTTP socket.
      txn_id = rack_env['PASSENGER_TXN_ID']
      return nil if !txn_id

      # Workaround for Ruby < 2.1 support where there is no function for querying
      # the monotonic time.
      delta_monotonic_env = rack_env['PASSENGER_DELTA_MONOTONIC']
      set_delta_monotonic(delta_monotonic_env.to_i) if delta_monotonic_env

      reporter = RequestReporter.new(context, txn_id, app_group_name, key)
      return if reporter.null?

      rack_env['union_station_hooks'] = reporter
      Thread.current[:union_station_hooks] = reporter
      reporter.log_request_begin
      reporter.log_gc_stats_on_request_begin
      reporter
    end

    # @note You do not have to call this! Passenger automatically calls
    #   this for you!
    #
    # Indicates that a Rack request, on which {begin_rack_request} was called,
    # has ended. You should call this method as late as possible during a
    # request, after all processing have ended. Preferably after the Rack
    # response body has closed.
    #
    # The {RequestReporter} object associated with this Rack request and with
    # the current, will be closed (by calling {RequestReporter#close}), which
    # finalizes the Union Station logs for this request.
    #
    # This method MUST be called in the same thread that called
    # {begin_rack_request}.
    #
    # It is undefined what will happen if you call this method a Rack request
    # on which {begin_rack_request} was not called, so don't do that.
    #
    # This method does nothing if it was already called on this Rack request.
    def end_rack_request(rack_env,
        uncaught_exception_raised_during_request = false)
      reporter = rack_env.delete('union_station_hooks')
      Thread.current[:union_station_hooks] = nil
      if reporter
        begin
          reporter.log_gc_stats_on_request_end
          reporter.log_request_end(uncaught_exception_raised_during_request)
        ensure
          reporter.close
        end
      end
    end

    # Logs an exception that did NOT occur during a request.
    #
    # This method should be used for logging exceptions outside the
    # request-response cycle, e.g. exceptions in threads. If you want to
    # log a request that occurred during a request, use
    # {RequestReporter#log_exception} instead. That method will also log
    # any related request-specific information, while this method does not.
    #
    # @param [Exception] exception
    # @since 2.1.0
    def log_exception(exception)
      transaction = context.new_transaction(app_group_name, :exceptions, key)
      begin
        return do_nothing_on_null(:log_exception) if transaction.null?

        base64_message = exception.message
        base64_message = exception.to_s if base64_message.empty?
        base64_message = Utils.base64(base64_message)
        base64_backtrace = Utils.base64(exception.backtrace.join("\n"))

        transaction.message("Message: #{base64_message}")
        transaction.message("Class: #{exception.class.name}")
        transaction.message("Backtrace: #{base64_backtrace}")
      ensure
        transaction.close
      end
    end

    # Returns an opaque object (a {TimePoint}) that represents a collection
    # of metrics about the current time.
    #
    # This TimePoint samples monotonic time (with a fallback to wall clock
    # time) as well as CPU time, time spent in userspace and kernel space,
    # time spent context switching, etc. The exact information contained 
    # in the object is operating system specific, hence the object is opaque.
    #
    # You should use it for the various API methods that require timing
    # information. Those methods also accept standard Ruby `Time` objects, 
    # but we strongly recommended against doing this, because wall clock
    # time can jump forwards and backwards, which may create issues.
    #
    # See {RequestReporter#log_controller_action} for an example of
    # an API method which expects timing information.
    # `RequestReporter#log_controller_action` expects you to
    # provide timing information about a controller action. That timing
    # information is supposed to be obtained by calling
    # `UnionStationHooks.now`.
    #
    # @return [TimePoint]
    def now
      monotime_usec = Utils.monotime_usec_now
      pt = Utils.process_times
      TimePoint.new(monotime_usec, pt.utime, pt.stime)
    end

    # Returns a best-estimate delta (usec) between the wallclock and 
    # the monotonic clock (updated every request), such that: 
    # time_monotic_usec = time_wallclock_usec - delta
    def get_delta_monotonic
      @mono_mutex.synchronize { @delta_monotonic }
    end

  private

    # Although the de-facto state seems to be that reading/writing instance variables
    # is MT-safe, it's not guaranteed so better safe than sorry here.
    def set_delta_monotonic(val)
      @mono_mutex.synchronize { @delta_monotonic = val }
    end

    def create_context
      require_lib('context')
      @@context = Context.new(config[:ust_router_address],
        config[:ust_router_username] || 'logging',
        config[:ust_router_password],
        config[:node_name])
    end

    def install_postfork_hook
      if defined?(PhusionPassenger)
        PhusionPassenger.on_event(:starting_worker_process) do |forked|
          if forked
            UnionStationHooks.context.clear_connection
          end
        end
      end
    end

    def install_event_pre_hook
      preprocessor = @@config[:event_preprocessor]
      if preprocessor
        define_singleton_method(:call_event_pre_hook, &preprocessor)
      else
        def call_event_pre_hook(_event)
          # Do nothing
        end
      end
    end

    def initialize_other_union_station_hooks_gems
      @@initializers.each do |initializer|
        initializer.initialize!
      end
    end

    def finalize_install
      @@config.freeze
      @@initializers.freeze
      @@app_group_name = @@config[:app_group_name]
      @@key = @@config[:union_station_key]
      if @@config[:debug]
        UnionStationHooks::Log.debugging = true
      end
      require_simple_json
      @mono_mutex = Mutex.new
      @delta_monotonic = 0
      @@initialized = true
    end
  end
end
