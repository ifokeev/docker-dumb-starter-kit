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
UnionStationHooks.require_lib 'message_channel'

module UnionStationHooks
  # Represents a connection to the UstRouter process.
  #
  # @private
  class Connection
    attr_reader :mutex
    attr_accessor :channel

    def initialize(io)
      @mutex = Mutex.new
      @refcount = 1
      @channel = MessageChannel.new(io) if io
    end

    def connected?
      !!@channel
    end

    def disconnect
      @channel.io.close if @channel
      @channel = nil
    end

    def ref
      @refcount += 1
    end

    def unref
      @refcount -= 1
      if @refcount == 0
        disconnect
      end
    end

    def synchronize
      @mutex.synchronize do
        yield
      end
    end
  end
end
