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

require 'shellwords'

TRAVIS_PASSENGER_BRANCH = 'master'

desc 'Run tests'
task :spec do
  pattern = ENV['E']
  if pattern
    args = "-e #{Shellwords.escape(pattern)}"
  end
  sh 'rm -rf coverage'
  sh "bundle exec rspec -c -f d spec/*_spec.rb #{args}"
end

task :test => :spec

desc 'Run tests in Travis'
task "spec:travis" do
  if !ENV['PASSENGER_CONFIG']
    Rake::Task['travis:install_passenger'].invoke
  end
  if ENV['TRAVIS_WITH_SUDO']
    sh 'cp ruby_versions.yml.travis-with-sudo ruby_versions.yml'
  else
    sh 'cp ruby_versions.yml.travis ruby_versions.yml'
  end
  Rake::Task['spec'].invoke
end

desc 'Build gem'
task :gem do
  sh 'gem build union_station_hooks_core.gemspec'
end

desc 'Check coding style'
task :rubocop do
  sh 'bundle exec rubocop -D lib'
end

desc 'Generate API documentation'
task :doc do
  sh 'rm -rf doc'
  sh 'bundle exec yard'
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
    sh "#{passenger_config} install-agent --auto"
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
    sh "#{passenger_config} install-agent --auto"
  end
end
