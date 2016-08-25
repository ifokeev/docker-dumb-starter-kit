#  Union Station - https://www.unionstationapp.com/
#  Copyright (c) 2015 Phusion Holding B.V.
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

TRAVIS_PASSENGER_BRANCH = 'master'

if defined?(Bundler)
  # Undo Bundler environment so that calls to 'bundle install' won't try to
  # access the .bundle directory in the gem's toplevel directory.
  clean_env = nil
  Bundler.with_clean_env do
    clean_env = ENV.to_hash
  end
  ENV.replace(clean_env)
  ARGV.each do |arg|
    if arg =~ /^(\w+)=(.*)$/m
      ENV[$1] = $2
    end
  end
end

ush_core_path = ENV['USH_CORE_PATH']
if ush_core_path
  require "#{ush_core_path}/lib/union_station_hooks_core"
else
  require 'union_station_hooks_core'
end

require File.expand_path(File.dirname(__FILE__) + '/lib/union_station_hooks_rails')

require 'shellwords'

desc 'Install the gem bundles of test apps'
task :install_test_app_bundles do
  bundle_args = ENV['BUNDLE_ARGS']
  Dir['rails_test_apps/*'].each do |dir|
    next if !should_run_rails_test?(dir)
    puts "Installing gem bundle for Rails #{File.basename(dir)}"
    sh "mkdir -p tmp.bundler"
    begin
      sh "cp #{dir}/Gemfile #{dir}/Gemfile.lock tmp.bundler/"

      puts "Editing tmp.bundler/Gemfile.lock"
      content = File.open("tmp.bundler/Gemfile.lock", "r") do |f|
        f.read
      end
      content.gsub!(/union_station_hooks_core \(.+\)/,
        "union_station_hooks_core (#{UnionStationHooks::VERSION_STRING})")
      content.gsub!(/union_station_hooks_rails \(.+\)/,
        "union_station_hooks_rails (#{UnionStationHooksRails::VERSION_STRING})")
      File.open("tmp.bundler/Gemfile.lock", "w") do |f|
        f.write(content)
      end

      sh "cd tmp.bundler && " \
        "ln -s #{Shellwords.escape UnionStationHooks::ROOT} ush_core && " \
        "ln -s #{Shellwords.escape UnionStationHooksRails::ROOT} ush_rails && " \
        "bundle install --without development doc #{bundle_args}"
    ensure
      sh "rm -rf tmp.bundler"
    end
  end
end

desc 'Run tests'
task :spec do
  if ENV['E']
    arg = "-e #{Shellwords.escape ENV['E']}"
  end
  sh "bundle exec rspec -c -f d #{arg}".strip
end

task :test => :spec

desc 'Run tests in Travis'
task "spec:travis" do
  if !ENV['PASSENGER_CONFIG']
    Rake::Task['travis:install_passenger'].invoke
  end
  Rake::Task['spec'].invoke
end

desc 'Build gem'
task :gem do
  sh 'gem build union_station_hooks_rails.gemspec'
end


namespace :travis do
  task :install_passenger do
    if File.exist?('../../../../../bin/passenger-config')
      # We are vendored into Passenger
      Rake::Task['travis:install_passenger_vendor'].invoke
    else
      Rake::Task['travis:install_passenger_git'].invoke
    end
  end

  task :install_passenger_vendor do
    passenger_config = File.expand_path('../../../../../bin/passenger-config')
    ENV['PASSENGER_CONFIG'] = passenger_config
    sh "#{passenger_config} install-standalone-runtime --auto"
  end

  task :install_passenger_git do
    if !File.exist?('passenger/.git')
      sh "git clone --recursive --branch #{TRAVIS_PASSENGER_BRANCH} git://github.com/phusion/passenger.git"
    else
      puts 'cd passenger'
      Dir.chdir('passenger') do
        sh 'git fetch'
        sh 'rake clean'
        sh "git reset --hard origin/#{TRAVIS_PASSENGER_BRANCH}"
        sh 'git submodule update --init --recursive'
      end
      puts 'cd ..'
    end

    passenger_config = "#{Dir.pwd}/passenger/bin/passenger-config"
    envs = {
      'PASSENGER_CONFIG' => passenger_config,
      'CC' => 'ccache cc',
      'CXX' => 'ccache c++',
      'CCACHE_COMPRESS' => '1',
      'CCACHE_COMPRESS_LEVEL' => '3',
      'CCACHE_DIR' => "#{Dir.pwd}/passenger/.ccache"
    }
    envs.each_pair do |key, val|
      ENV[key] = val
      puts "$ export #{key}='#{val}'"
    end
    sh 'mkdir -p passenger/.ccache'
    sh "#{passenger_config} install-standalone-runtime --auto"
  end
end


def should_run_rails_test?(dir)
  # Rails >= 4.0 requires Ruby >= 1.9
  RUBY_VERSION >= '1.9' || File.basename(dir) < '4.0'
end
