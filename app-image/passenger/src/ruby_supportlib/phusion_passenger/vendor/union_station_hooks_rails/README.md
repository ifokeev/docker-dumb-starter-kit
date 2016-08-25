# Union Station Ruby on Rails hooks

[![Build Status](https://travis-ci.org/phusion/union_station_hooks_rails.svg?branch=master)](https://travis-ci.org/phusion/union_station_hooks_rails)

[Union Station](https://www.unionstationapp.com) is a web application monitoring and performance analytics platform for Ruby. In order for Union Station to analyze your application, your application must send data to Union Station. This gem allows you to do that.

`union_station_hooks_rails` is a gem that automatically hooks into various parts of Rails, so that the right information is sent to Union Station. Under the hood, it makes use of the APIs provided by [union_station_hooks_core](https://github.com/phusion/union_station_hooks_core).

**Resources:** [About Union Station](https://www.unionstationapp.com) | [Github](https://github.com/phusion/union_station_hooks_rails)

**Table of contents**

 * [Installation](#installation)
   - [Using with Passenger](#using-with-passenger)
   - [Overriding Passenger's version](#overriding-passengers-version)
   - [Using without Passenger](#using-without-passenger)
 * [Legacy code](#legacy-code)
 * [Contributing](contributing)

---

## Installation

### Using with Passenger

**Note: This documentation section only applies to Passenger 5.0.20 or later!**

If you use [Passenger](https://www.phusionpassenger.com/), then you do not need to install the `union_station_hooks_rails` gem. `union_station_hooks_rails` is bundled with Passenger.

The only thing you need to do is to create a file `config/initializers/union_station.rb` in which you call this code:

    if defined?(UnionStationHooks)
      UnionStationHooks.initialize!
    end

(Are you already calling `PhusionPassenger.install_framework_extensions!` from somewhere in your codebase? Please read [Legacy code](#legacy-code) for important information.)

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

Each version of Passenger bundles its own version of the `union_station_hooks_rails` gem (and the `union_station_hooks_core` gem, which is a dependency). The Passenger maintainers regularly update their bundled versions with the latest version. Sometimes, you may wish to use a specific version of `union_station_hooks_rails` and `union_station_hooks_core`, overriding the versions that came bundled with Passenger. For example, we have may published a new version of `union_station_hooks_rails` with some bug fixes, even though Passenger hasn't been updated yet.

You can override Passenger's bundled versions as follows.

 1. Add the gems you want to override to your Gemfile, like this:

        # Uncomment the following line if you want to override Passenger's
        # bundled version
        #gem 'union_station_hooks_core'

        gem 'union_station_hooks_rails'

 2. Install your gem bundle:

        bundle install

### Using without Passenger

It is currently not possible to use Union Station without Passenger. If you would like to have this feature, please let us know.

## Legacy code

Before Passenger 5.0.20, the Union Station setup instructions used to tell you to create a `config/initializers/passenger.rb` in which you call the following code:

    PhusionPassenger.install_framework_extensions! if defined?(PhusionPassenger)

Since Passenger 5.0.20, `PhusionPassenger.install_framework_extensions!` has become an alias for `UnionStationHooks.initialize!`, but the former is considered deprecated. Please replace the above code with:

    if defined?(UnionStationHooks)
      UnionStationHooks.initialize!
    end

And please also rename `config/initializers/passenger.rb` to `config/initializers/union_station.rb`.

## Contributing

Looking to contribute to this gem? Please read the documentation in the [hacking/](https://github.com/phusion/union_station_hooks_rails/blob/master/hacking) directory.
