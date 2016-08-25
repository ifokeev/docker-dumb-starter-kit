# Union Station Ruby hooks core

[![Build Status](https://travis-ci.org/phusion/union_station_hooks_core.svg?branch=master)](https://travis-ci.org/phusion/union_station_hooks_core)

[Union Station](https://www.unionstationapp.com) is a web application monitoring and performance analytics platform for Ruby. In order for Union Station to analyze your application, your application must send data to Union Station. This gem allows you to do that.

`union_station_hooks_core` is a web-framework-agnostic gem that **hooks into various Ruby internals** in order to send generic Ruby application analytics information to Union Station. Not all information can be automatically inferred by hooking into the Ruby internals, so this gem also provides an **API** that you can call at key places in the codebase to supply the right information.

### Using Ruby on Rails?

If your application is a Rails application, then you should use the [union_station_hooks_rails](https://github.com/phusion/union_station_hooks_rails) gem instead of this gem. `union_station_hooks_rails` automatically hooks into Rails to send the right information to Union Station, so that you don't have to call any APIs. Under the hood, `union_station_hooks_rails` makes use of the `union_station_hooks_core` API.

**Resources:** [About Union Station](https://www.unionstationapp.com) | [Github](https://github.com/phusion/union_station_hooks_core) | [API docs](http://www.rubydoc.info/github/phusion/union_station_hooks_core/UnionStationHooks)

**Table of contents**

 * [Installation](#installation)
   - [Using with Passenger](#using-with-passenger)
   - [Overriding Passenger's version](#overriding-passengers-version)
   - [Using without Passenger](#using-without-passenger)
 * [API](#api)
 * [Legacy code](#legacy-code)
 * [Contributing](contributing)

---

## Installation

### Using with Passenger

**Note: This documentation section only applies to Passenger 5.0.20 or later!**

If you use [Passenger](https://www.phusionpassenger.com/), then you do not need to install the `union_station_hooks_core` gem. `union_station_hooks_core` is bundled with Passenger.

The only thing you need to do is to ensure that the code is called during application startup:

    if defined?(UnionStationHooks)
      UnionStationHooks.initialize!
    end

(Are you already calling `PhusionPassenger.install_framework_extensions!` from somewhere in your codebase? Please read [Legacy code](#legacy-code) for important information.)

A good place to call this is in your Rackup file, `config.ru`. Or if you are using Rails, you should create a file `config/initializers/union_station.rb` in which you call this.

When you have this call in place, enable Union Station support in Passenger. Here are some examples:

 * _Passenger with Nginx integration mode_<br>

   Insert the following config in your virtual host configuration, then restart Nginx:

        union_station_support on;
        union_station_key <YOUR KEY HERE>;

 * _Passenger with Apache integration mode_<br>

   Insert the following config in your virtual host configuration, then restart Apache:

        UnionStationSupport on
        UnionStationKey <YOUR KEY HERE>

 * _Passenger Standalone_<br>

   Start Passenger with the `--union-station-key` parameter:

        $ passenger start --union-station-key <YOUR KEY HERE>

   Or set the `union_station_key` configuration option in Passengerfile.json:

        {
            "union_station_key": "<YOUR KEY HERE>"
        }

### Overriding Passenger's version

**_Note: Are you using `union_station_hooks_rails`? Read [these instructions](https://github.com/phusion/union_station_hooks_rails#overriding-passengers-version) instead._**

Each version of Passenger bundles its own version of the `union_station_hooks_core` gem. The Passenger maintainers regularly update their bundled version with the latest version. Sometimes, you may wish to use a specific version of `union_station_hooks_core`, overriding the version that came bundled with Passenger. For example, we have may published a new version of `union_station_hooks_core` with some bug fixes, even though Passenger hasn't been updated yet.

You can override Passenger's bundled version as follows.

 1. Add `union_station_hooks_core` to your Gemfile, like this:

        gem 'union_station_hooks_core'

 2. Install your gem bundle:

        bundle install

 3. Ensure that your application calls `require 'union_station_hooks_core'` during startup, before you access anything in the `UnionStationHooks` module (so before the `UnionStationHooks.initialize!` call).

    If you are using Rails, then Rails takes care of that automatically by calling `Bundler.require` in `config/application.rb`, so in that case you don't need to follow this step.

### Using without Passenger

It is currently not possible to use Union Station without Passenger. If you would like to have this feature, please let us know.

## API

Please refer to [the API documentation website](http://www.rubydoc.info/github/phusion/union_station_hooks_core/UnionStationHooks).

## Legacy code

Before Passenger 5.0.20, the Union Station setup instructions used to tell you to create a `config/initializers/passenger.rb` in which you call the following code:

    PhusionPassenger.install_framework_extensions! if defined?(PhusionPassenger)

Since Passenger 5.0.20, `PhusionPassenger.install_framework_extensions!` has become an alias for `UnionStationHooks.initialize!`, but the former is considered deprecated. Please replace the above code with:

    if defined?(UnionStationHooks)
      UnionStationHooks.initialize!
    end

And please also rename `config/initializers/passenger.rb` to `config/initializers/union_station.rb`.

## Contributing

Looking to contribute to this gem? Please read the documentation in the [hacking/](https://github.com/phusion/union_station_hooks_core/blob/master/hacking) directory.
