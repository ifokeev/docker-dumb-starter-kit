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
    ###### Logging view rendering-related information ######

    # Logs timing information about the rendering of a single view, template or
    # partial. This form expects a block, which is to perform the
    # view/template/partial rendering. Timing information is collected before
    # and after the block returns.
    #
    # The `union_station_hooks_rails` gem automatically calls this for you
    # if your application is a Rails app. It will call this on every view
    # or partial rendering.
    #
    # @param [String] name Name of the view, template or partial that is being
    #   rendered.
    # @yield The given block is expected to perform the actual view rendering.
    # @return The return value of the block.
    def log_view_rendering_block(name, &block)
      if null?
        do_nothing_on_null(:log_view_rendering_block)
        yield
      else
        @transaction.log_activity_block(next_view_rendering_name,
          name, &block)
      end
    end

    # Logs timing information about the rendering of a single view, template or
    # partial.
    #
    # Unlike {#log_view_rendering_block}, this form does not expect a block.
    # However, you are expected to pass timing information to the options
    # hash.
    #
    # The `union_station_hooks_rails` gem automatically calls
    # {#log_view_rendering_block} for you if your application is a Rails app.
    # It will call this on every view or partial rendering.
    #
    # @option options [String] :name Name of the view, template or partial
    #   that is being rendered.
    # @option options [TimePoint or Time] :begin_time The time at which this
    #   view rendering begun. See {UnionStationHooks.now} to learn more.
    # @option options [TimePoint or Time] :end_time The time at which this view
    #   rendering ended. See {UnionStationHooks.now} to learn more.
    # @option options [Boolean] :has_error (optional) Whether an uncaught
    #   exception occurred during the view rendering. Default: false.
    def log_view_rendering(options)
      return do_nothing_on_null(:log_view_rendering) if null?
      Utils.require_key(options, :name)
      Utils.require_key(options, :begin_time)
      Utils.require_key(options, :end_time)

      @transaction.log_activity(next_view_rendering_name,
        options[:begin_time], options[:end_time],
        options[:name], options[:has_error])
    end

  private

    def next_view_rendering_name
      result = @next_view_rendering_number
      @next_view_rendering_number += 1
      "view rendering #{result}"
    end
  end
end
