# Configuration keys

## `:union_station_key`

Default: automatically set by Passenger

## `:app_group_name`

Default: automatically set by Passenger

## `:ust_router_address`

Default: automatically set by Passenger

## `:ust_router_password`

Default: automatically set by Passenger

## `:node_name`

Default: current host name

## `:event_preprocessor`

Default: none

## `:debug`

Default: false

Whether to print debugging messages for `union_station_hooks_*` gems.

## `:check_initialized`

Default: true

If enabled, and Union Station support in Passenger is enabled too, then Passenger will complain during application startup if the application never called `UnionStationHooks.initialize!`.
