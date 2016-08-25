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

require 'thread'

module UnionStationHooks
  class RequestReporter
    ###### Logging basic request information ######

    # A mutex for synchronizing GC stats reporting. We do this because in
    # multithreaded situations we don't want to interleave GC stats access with
    # calls to `GC.clear_stats`. Not that GC stats are very helpful in
    # multithreaded situations, but this is better than nothing.
    #
    # @private
    GC_MUTEX = Mutex.new

    # @private
    OBJECT_SPACE_SUPPORTS_LIVE_OBJECTS = ObjectSpace.respond_to?(:live_objects)

    # @private
    OBJECT_SPACE_SUPPORTS_ALLOCATED_OBJECTS =
      ObjectSpace.respond_to?(:allocated_objects)

    # @private
    OBJECT_SPACE_SUPPORTS_COUNT_OBJECTS =
      ObjectSpace.respond_to?(:count_objects)

    # @private
    GC_SUPPORTS_TIME = GC.respond_to?(:time)

    # @private
    GC_SUPPORTS_CLEAR_STATS = GC.respond_to?(:clear_stats)

    # Logs the beginning of a Rack request. This is automatically called
    # from {UnionStationHooks.begin_rack_request} (and thus automatically
    # from Passenger).
    #
    # @private
    def log_request_begin
      return do_nothing_on_null(:log_request_begin) if null?
      @transaction.log_activity_begin('app request handler processing')
    end

    # Logs the end of a Rack request. This means that the Rack response body
    # has been written out, and that the `#close` has been called on the Rack
    # response body.
    #
    # This does not necessarily indicate that any buffering mechanism in
    # between the app and the client (e.g. Nginx, or the Passenger core) is
    # done flushing the response to the client.
    #
    # This is automatically called from {UnionStationHooks.begin_rack_request}
    # (and thus automatically from Passenger).
    #
    # @private
    def log_request_end(uncaught_exception_raised_during_request = false)
      return do_nothing_on_null(:log_request_end) if null?
      @transaction.log_activity_end('app request handler processing',
        UnionStationHooks.now, uncaught_exception_raised_during_request)
    end

    # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity

    # @private
    def log_gc_stats_on_request_begin
      return do_nothing_on_null(:log_gc_stats_on_request_begin) if null?

      # See the docs for MUTEX on why we synchronize this.
      GC_MUTEX.synchronize do
        if OBJECT_SPACE_SUPPORTS_LIVE_OBJECTS
          @transaction.message('Initial objects on heap: ' \
            "#{ObjectSpace.live_objects}")
        end
        if OBJECT_SPACE_SUPPORTS_ALLOCATED_OBJECTS
          @transaction.message('Initial objects allocated so far: ' \
            "#{ObjectSpace.allocated_objects}")
        elsif OBJECT_SPACE_SUPPORTS_COUNT_OBJECTS
          count = ObjectSpace.count_objects
          @transaction.message('Initial objects allocated so far: ' \
            "#{count[:TOTAL] - count[:FREE]}")
        end
        if GC_SUPPORTS_TIME
          @transaction.message("Initial GC time: #{GC.time}")
        end
      end
    end

    # @private
    def log_gc_stats_on_request_end
      return do_nothing_on_null(:log_gc_stats_on_request_end) if null?

      # See the docs for MUTEX on why we synchronize this.
      GC_MUTEX.synchronize do
        if OBJECT_SPACE_SUPPORTS_LIVE_OBJECTS
          @transaction.message('Final objects on heap: ' \
            "#{ObjectSpace.live_objects}")
        end
        if OBJECT_SPACE_SUPPORTS_ALLOCATED_OBJECTS
          @transaction.message('Final objects allocated so far: ' \
            "#{ObjectSpace.allocated_objects}")
        elsif OBJECT_SPACE_SUPPORTS_COUNT_OBJECTS
          count = ObjectSpace.count_objects
          @transaction.message('Final objects allocated so far: ' \
            "#{count[:TOTAL] - count[:FREE]}")
        end
        if GC_SUPPORTS_TIME
          @transaction.message("Final GC time: #{GC.time}")
        end
        if GC_SUPPORTS_CLEAR_STATS
          # Clear statistics to void integer wraps.
          GC.clear_stats
        end
      end
    end

    # rubocop:enable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity

    # Logs that the application server is about to write out the Rack
    # response body.
    #
    # This call *must* be followed by a call to {#log_writing_rack_body_end}
    # some time later.
    #
    # This is automatically called by Passenger's Rack handler.
    #
    # @private
    # @return An ID to be passed later to {#log_writing_rack_body_end}, or nil
    #   on error.
    def log_writing_rack_body_begin
      return do_nothing_on_null(:log_writing_rack_body_begin) if null?
      @transaction.log_activity_begin('app writing out response body')
      :writing_rack_body # Random non-nil ID
    end

    # Logs that the application server is done writing out the Rack
    # response body. This does not necessarily indicate that any buffering
    # mechanism in between the app and the client (e.g. Nginx, or the Passenger
    # core) is done flushing the response to the client.
    #
    # This is automatically called by Passenger's Rack handler.
    #
    # @private
    def log_writing_rack_body_end(id)
      return do_nothing_on_null(:log_writing_rack_body_end) if null?
      return if id.nil?
      @transaction.log_activity_end('app writing out response body')
    end

    # Logs that the application server is about to call `#close` on the
    # Rack body object.
    #
    # This call *must* be followed by a call to {#log_closing_rack_body_end}
    # some time later.
    #
    # This is automatically called by Passenger's Rack handler.
    #
    # @private
    # @return An ID to be passed later to {#log_closing_rack_body_end}, or nil
    #   on error.
    def log_closing_rack_body_begin
      return do_nothing_on_null(:log_closing_rack_body_begin) if null?
      @transaction.log_activity_begin('closing rack body object')
      :closing_rack_body # Random non-nil ID
    end

    # Logs that the application server is done calling `#close` on the
    # Rack body object.
    #
    # This is automatically called by Passenger's Rack handler.
    #
    # @private
    def log_closing_rack_body_end(id)
      return do_nothing_on_null(:log_closing_rack_body_end) if null?
      return if id.nil?
      @transaction.log_activity_end('closing rack body object')
    end
  end
end
