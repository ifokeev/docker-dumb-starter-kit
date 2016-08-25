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

UnionStationHooks.require_lib 'request_reporter/basics'
UnionStationHooks.require_lib 'request_reporter/controllers'
UnionStationHooks.require_lib 'request_reporter/view_rendering'
UnionStationHooks.require_lib 'request_reporter/misc'

module UnionStationHooks
  # A RequestReporter object is used for logging request-specific information
  # to Union Station. "Information" may include (and are not limited to):
  #
  #  * Web framework controller and action name.
  #  * Exceptions raised during the request.
  #  * Cache hits and misses.
  #  * Database actions.
  #
  # A unique RequestReporter is created by Passenger at the beginning of every
  # request (by calling {UnionStationHooks.begin_rack_request}). This object is
  # closed at the end of the same request (after the Rack body object is
  # closed).
  #
  # As an application developer, the RequestReporter is the main class
  # that you will be interfacing with. See the {UnionStationHooks} module
  # description for an example of how you can use RequestReporter.
  #
  # ## Obtaining a RequestReporter
  #
  # You are not supposed to create a RequestReporter object directly.
  # You are supposed to obtain the RequestReporter object that Passenger creates
  # for you. This is done through the `union_station_hooks` key in the Rack
  # environment hash, as well as through the `:union_station_hooks` key in
  # the current thread's object:
  #
  #     env['union_station_hooks']
  #     # => RequestReporter object or nil
  #
  #     Thread.current[:union_station_hooks]
  #     # => RequestReporter object or nil
  #
  # Note that Passenger may not have created such an object because of an
  # error. At present, there are two error conditions that would cause a
  # RequestReporter object not to be created. However, your code should take
  # into account that in the future more error conditions may trigger this.
  #
  #  1. There is no transaction ID associated with the current request.
  #     When Union Station support is enabled in Passenger, Passenger always
  #     assigns a transaction ID. However, administrators can also
  #     {https://www.phusionpassenger.com/library/admin/nginx/request_individual_processes.html
  #     access Ruby processes directly} through process-private HTTP sockets,
  #     bypassing Passenger's load balancing mechanism. In that case, no
  #     transaction ID will be assigned.
  #  2. An error occurred recently while sending data to the UstRouter, either
  #     because the UstRouter crashed or because of some other kind of
  #     communication error occurred. This error condition isn't cleared until
  #     certain a timeout has passed.
  #
  #     The UstRouter is a Passenger process which runs locally and is
  #     responsible for aggregating Union Station log data from multiple
  #     processes, with the goal of sending the aggregate data over the network
  #     to the Union Station service.
  #
  #     This kind of error is automatically recovered from after a certain
  #     period of time.
  #
  # ## Null mode
  #
  # The error condition 2 described above may also cause an existing
  # RequestReporter object to enter the "null mode". When this mode is entered,
  # any further actions on the RequestReporter object will become no-ops.
  # You can check whether the null mode is active by calling {#null?}.
  #
  # Closing a RequestReporter also causes it to enter the null mode.
  #
  # ## Thread-safety
  #
  # RequestReporter is *not* thread-safe. If you access it concurrently, be sure
  # to wrap its operations in a mutex.
  class RequestReporter
    # Returns a new RequestReporter object. You should not call
    # `RequestReporter.new` directly. See "Obtaining a RequestReporter"
    # in the {RequestReporter class description}.
    #
    # @api private
    def initialize(context, txn_id, app_group_name, key)
      raise ArgumentError, 'Transaction ID must be given' if txn_id.nil?
      raise ArgumentError, 'App group name must be given' if app_group_name.nil?
      raise ArgumentError, 'Union Station key must be given' if key.nil?
      @context = context
      @txn_id = txn_id
      @app_group_name = app_group_name
      @key = key
      @transaction = continue_transaction
      @next_view_rendering_number = 1
      @next_user_activity_number = 1
      @next_benchmark_number = 1
      @next_database_query_number = 1
    end

    # Indicates that no further information will be logged for this
    # request.
    #
    # @api private
    def close
      @transaction.close
    end

    # Returns whether is this RequestReporter object is in null mode.
    # See the {RequestReporter class description} for more information.
    def null?
      @transaction.null?
    end

    # Other methods are implemented in the files in the
    # 'request_reporter/' subdirectory.

  private

    def continue_transaction
      @context.continue_transaction(@txn_id, @app_group_name,
        :requests, @key)
    end

    # Called when one of the methods return early upon detecting null
    # mode. Used by tests to verify that methods return early.
    def do_nothing_on_null(_source)
      # Do nothing by default. Tests will stub this.
    end
  end
end
