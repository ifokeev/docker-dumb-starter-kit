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

UnionStationHooks.require_lib 'log'
UnionStationHooks.require_lib 'context'
UnionStationHooks.require_lib 'time_point'
UnionStationHooks.require_lib 'utils'

module UnionStationHooks
  # @private
  class Transaction
    attr_reader :txn_id

    def initialize(connection, txn_id)
      @connection = connection
      @txn_id = txn_id
      if connection
        raise ArgumentError, 'Transaction ID required' if txn_id.nil?
        connection.ref
      end
    end

    def null?
      !@connection || !@connection.connected?
    end

    def message(text)
      if !@connection
        log_message_to_null(text)
        return
      end

      @connection.synchronize do
        if !@connection.connected?
          log_message_to_null(text)
          return
        end

        UnionStationHooks::Log.debug('[Union Station log] ' \
          "#{@txn_id} #{Utils.encoded_timestamp} #{text}")

        io_operation do
          @connection.channel.write('log', @txn_id, Utils.encoded_timestamp)
          @connection.channel.write_scalar(text)
        end
      end
    end

    def log_activity_block(name, extra_info = nil)
      has_error = false
      log_activity_begin(name, UnionStationHooks.now, extra_info)
      begin
        yield
      rescue Exception
        has_error = true
        is_closed = closed?
        raise
      ensure
        if !is_closed
          log_activity_end(name, UnionStationHooks.now, has_error)
        end
      end
    end

    def log_activity_begin(name, time = UnionStationHooks.now, extra_info = nil)
      if extra_info
        extra_info_base64 = Utils.base64(extra_info)
      else
        extra_info_base64 = nil
      end
      if time.is_a?(TimePoint)
        message "BEGIN: #{name} (#{time.monotime.to_s(36)}," \
          "#{time.utime.to_s(36)},#{time.stime.to_s(36)}) " \
          "#{extra_info_base64}"
      else
        message "BEGIN: #{name} (#{Utils.monotime_usec_from_time(time).to_s(36)})" \
          " #{extra_info_base64}"
      end
    end

    def log_activity_end(name, time = UnionStationHooks.now, has_error = false)
      if time.is_a?(TimePoint)
        if has_error
          message "FAIL: #{name} (#{time.monotime.to_s(36)}," \
            "#{time.utime.to_s(36)},#{time.stime.to_s(36)})"
        else
          message "END: #{name} (#{time.monotime.to_s(36)}," \
            "#{time.utime.to_s(36)},#{time.stime.to_s(36)})"
        end
      else
        if has_error
          message "FAIL: #{name} (#{Utils.monotime_usec_from_time(time).to_s(36)})"
        else
          message "END: #{name} (#{Utils.monotime_usec_from_time(time).to_s(36)})"
        end
      end
    end

    def log_activity(name, begin_time, end_time, extra_info = nil,
                     has_error = false)
      log_activity_begin(name, begin_time, extra_info)
      log_activity_end(name, end_time, has_error)
    end

    def close
      return if !@connection

      @connection.synchronize do
        return if !@connection.connected?

        begin
          io_operation do
            # We need an ACK here so that we the UstRouter doesn't end up
            # processing the Core's openTransaction and closeTransaction pair
            # before it has received this process's openTransaction command.
            @connection.channel.write('closeTransaction', @txn_id,
              Utils.encoded_timestamp, true)
            Utils.process_ust_router_reply(@connection.channel,
              "Error handling reply for 'closeTransaction' message")
          end
        ensure
          @connection.unref
          @connection = nil
        end
      end
    end

    def closed?
      return nil if !@connection
      @connection.synchronize do
        !@connection.connected?
      end
    end

  private

    def log_message_to_null(text)
      UnionStationHooks::Log.debug('[Union Station log to null] ' \
        "#{@txn_id} #{Utils.encoded_timestamp} #{text}")
    end

    def io_operation
      yield
    rescue SystemCallError, IOError => e
      @connection.disconnect
      UnionStationHooks::Log.warn(
        "Error communicating with the UstRouter: #{e.message}")
    rescue Exception => e
      @connection.disconnect
      raise e
    end
  end
end
