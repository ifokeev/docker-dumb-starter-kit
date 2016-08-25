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

# This file contains union_station_hook_rails's version number. It is meant
# to be read and evaluated by the gemspec. We do not define any functions or
# modules here because we need to support the following situation:
#
# 1. Passenger loads its vendored union_station_hooks_* gems. This defines
#    various modules.
# 2. The app specified union_station_hooks_* gems in its Gemfile, which
#    indicates that it wants to override Passenger's vendored
#    union_station_hooks_* gems with its own versions. This will cause Bundler
#    to load union_station_hooks_*.gemspec.
#
# To make the gemspecs load properly and without affecting the already-loaded
# union_station_hooks_* gems code, we must not define any functions or modules
# here.

{
  :major  => 2,
  :minor  => 0,
  :tiny   => 1,
  :string => '2.0.1'
}
