# encoding: binary
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


module UnionStationHooks
  # This class allows reading and writing structured messages over
  # I/O channels. This is the Ruby implementation of Passenger's
  # src/cxx_supportlib/Utils/MessageIO.h; see that file for more information.
  #
  # @private
  class MessageChannel
    HEADER_SIZE = 2
    DELIMITER = "\0"
    DELIMITER_NAME = 'null byte'
    UINT16_PACK_FORMAT = 'n'
    UINT32_PACK_FORMAT = 'N'

    class InvalidHashError < StandardError
    end

    # The wrapped IO object.
    attr_accessor :io

    # Create a new MessageChannel by wrapping the given IO object.
    def initialize(io = nil)
      @io = io
      # Make it binary just in case.
      @io.binmode if @io
    end

    # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity, Metrics/AbcSize

    # Read an array message from the underlying file descriptor.
    # Returns the array message as an array, or nil when end-of-stream has
    # been reached.
    #
    # Might raise SystemCallError, IOError or SocketError when something
    # goes wrong.
    def read
      buffer = new_buffer
      if !@io.read(HEADER_SIZE, buffer)
        return nil
      end
      while buffer.size < HEADER_SIZE
        tmp = @io.read(HEADER_SIZE - buffer.size)
        if tmp.empty?
          return nil
        else
          buffer << tmp
        end
      end

      chunk_size = buffer.unpack(UINT16_PACK_FORMAT)[0]
      if !@io.read(chunk_size, buffer)
        return nil
      end
      while buffer.size < chunk_size
        tmp = @io.read(chunk_size - buffer.size)
        if tmp.empty?
          return nil
        else
          buffer << tmp
        end
      end

      message = []
      offset = 0
      delimiter_pos = buffer.index(DELIMITER, offset)
      while !delimiter_pos.nil?
        if delimiter_pos == 0
          message << ''
        else
          message << buffer[offset..delimiter_pos - 1]
        end
        offset = delimiter_pos + 1
        delimiter_pos = buffer.index(DELIMITER, offset)
      end
      message
    rescue Errno::ECONNRESET
      nil
    end

    # rubocop:enable Metrics/MethodLength, Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity, Metrics/AbcSize

    # Send an array message, which consists of the given elements, over the
    # underlying file descriptor. _name_ is the first element in the message,
    # and _args_ are the other elements. These arguments will internally be
    # converted to strings by calling to_s().
    #
    # Might raise SystemCallError, IOError or SocketError when something
    # goes wrong.
    def write(name, *args)
      check_argument(name)
      args.each do |arg|
        check_argument(arg)
      end

      message = "#{name}#{DELIMITER}"
      args.each do |arg|
        message << arg.to_s << DELIMITER
      end
      @io.write([message.size].pack('n') << message)
      @io.flush
    end

    # Send a scalar message over the underlying IO object.
    #
    # Might raise SystemCallError, IOError or SocketError when something
    # goes wrong.
    def write_scalar(data)
      @io.write([data.size].pack('N') << data)
      @io.flush
    end

  private

    def check_argument(arg)
      if arg.to_s.index(DELIMITER)
        raise ArgumentError,
          "Message name and arguments may not contain #{DELIMITER_NAME}"
      end
    end

    if defined?(ByteString)
      def new_buffer
        ByteString.new
      end
    else
      def new_buffer
        ''
      end
    end
  end
end # module UnionStationHooks
