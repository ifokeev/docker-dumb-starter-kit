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

module UnionStationHooks
  class RequestReporter
    ###### Logging controller-related information ######

    # Logs that you are calling a web framework controller action. Of course,
    # you should only call this if your web framework has the concept of
    # controller actions. For example Rails does, but Sinatra and Grape
    # don't.
    #
    # This form takes an options hash as well as a block. You can pass
    # additional information about the web framework controller action, which
    # will be logged. The block is expected to perform the actual request
    # handling. When the block returns, timing information about the block is
    # automatically logged.
    #
    # See also {#log_controller_action} for a form that doesn't
    # expect a block.
    #
    # The `union_station_hooks_rails` gem automatically calls this for you
    # if your application is a Rails app.
    #
    # @yield The given block is expected to perform request handling.
    # @param [Hash] options Information about the controller action.
    #   All options are optional.
    # @option options [String] :controller_name
    #   The controller's name, e.g. `PostsController`.
    # @option options [String] :action_name
    #   The controller action's name, e.g. `create`.
    # @option options [String] :method
    #   The HTTP method that the web framework thinks this request should have,
    #   e.g. `GET` and `PUT`. The main use case for this option is to support
    #   Rails's HTTP verb emulation. Rails uses a parameter named
    #   [`_method`](http://guides.rubyonrails.org/form_helpers.html#how-do-forms-with-patch-put-or-delete-methods-work-questionmark)
    #   to emulate HTTP verbs besides GET and POST. Other web frameworks may
    #   have a similar mechanism.
    # @return The return value of the block.
    #
    # @example Rails example
    #   # This example shows what to put inside a Rails controller action
    #   # method. Note that all of this is automatically done for you if you
    #   # use the union_station_hooks_rails gem.
    #   options = {
    #     :controller_name => self.class.name,
    #     :action_name => action_name,
    #     :method => request.request_method
    #   }
    #   reporter.log_controller_action_block(options) do
    #     do_some_request_processing_here
    #   end
    def log_controller_action_block(options = {})
      if null?
        do_nothing_on_null(:log_controller_action_block)
        yield
      else
        build_full_controller_action_string(options)
        has_error = true
        begin_time = UnionStationHooks.now
        begin
          result = yield
          has_error = false
          result
        ensure
          log_controller_action(
            options.merge(
              :begin_time => begin_time,
              :end_time => UnionStationHooks.now,
              :has_error => has_error
            )
          )
        end
      end
    end

    # Logs that you are calling a web framework controller action. Of course,
    # you should only call this if your web framework has the concept of
    # controller actions. For example Rails does, but Sinatra and Grape
    # don't.
    #
    # You can pass additional information about the web framework controller
    # action, which will be logged.
    #
    # Unlike {#log_controller_action_block}, this form does not expect a block.
    # However, you are expected to pass timing information to the options
    # hash.
    #
    # The `union_station_hooks_rails` gem automatically calls
    # {#log_controller_action_block} for you if your application is a Rails
    # app.
    #
    # @param [Hash] options Information about the controller action.
    # @option options [String] :controller_name (optional)
    #   The controller's name, e.g. `PostsController`.
    # @option options [String] :action_name (optional if :controller_name
    #   isn't set) The controller action's name, e.g. `create`.
    # @option options [String] :method (optional)
    #   The HTTP method that the web framework thinks this request should have,
    #   e.g. `GET` and `PUT`. The main use case for this option is to support
    #   Rails's HTTP verb emulation. Rails uses a parameter named
    #   [`_method`](http://guides.rubyonrails.org/form_helpers.html#how-do-forms-with-patch-put-or-delete-methods-work-questionmark)
    #   to emulate HTTP verbs besides GET and POST. Other web frameworks may
    #   have a similar mechanism.
    # @option options [TimePoint or Time] :begin_time The time at which the
    #   controller action begun. See {UnionStationHooks.now} to learn more.
    # @option options [TimePoint or Time] :end_time The time at which the
    #   controller action ended. See {UnionStationHooks.now} to learn more.
    # @option options [Boolean] :has_error (optional) Whether an uncaught
    #   exception occurred during the request. Default: false.
    #
    # @example
    #   # This example shows what to put inside a Rails controller action
    #   # method. Note that all of this is automatically done for you if you
    #   # use the union_station_hooks_rails gem.
    #   options = {
    #     :controller_name => self.class.name,
    #     :action_name => action_name,
    #     :method => request.request_method,
    #     :begin_time => UnionStationHooks.now
    #   }
    #   begin
    #     do_some_request_processing_here
    #   rescue Exception
    #     options[:has_error] = true
    #     raise
    #   ensure
    #     options[:end_time] = UnionStationHooks.now
    #     reporter.log_controller_action(options)
    #   end
    def log_controller_action(options)
      return do_nothing_on_null(:log_controller_action) if null?
      Utils.require_key(options, :begin_time)
      Utils.require_key(options, :end_time)

      if options[:controller_name]
        build_full_controller_action_string(options)
        @transaction.message("Controller action: #{@controller_action}")
      end
      if options[:method]
        @transaction.message("Application request method: #{options[:method]}")
      end
      @transaction.log_activity('framework request processing',
        options[:begin_time], options[:end_time], nil, options[:has_error])
    end

    # Returns whether {#log_controller_action_block} or
    # {#log_controller_action} has been called during this request.
    #
    # @return [Boolean]
    def controller_action_logged?
      !!@controller_action
    end

  private

    def build_full_controller_action_string(options)
      if options[:controller_name]
        Utils.require_key(options, :action_name)
        @controller_action = "#{options[:controller_name]}#" \
          "#{options[:action_name]}"
      end
    end
  end
end
