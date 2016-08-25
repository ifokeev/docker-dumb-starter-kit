# About

This repository contains a very dumb docker starter-kit to launch Nginx and Passenger containers fast.
Passenger can serve NodeJS, Ruby or Python App. 

## Features

* Serving NodeJS, Ruby or Python Apps via Passenger
* One container – one process
* Quick start with Thor

## Quick start

To start working with `Thor` type in your console:

```bash
bundle install
```

`Bundler` should be installed


List of available `Thor` commands: 

```bash
➜  thor list
d
-
thor d:build:app          # Build an app image from app-image folder
thor d:exec:sh CONTAINER  # system shell on container
thor d:rm:containers      # Stop and remove all created containers
thor d:run:default        # Run default runtime for Node App and Ruby app
thor d:run:mongo          # Run mongodb container
thor d:run:nginx          # Run Nginx container
thor d:run:node_app       # Run Node App container based on app-image image
thor d:run:postgres       # Run PostgreSQL container
thor d:run:redis          # Run redis container
thor d:run:ruby_app       # Run Ruby App container based on app-image image
thor d:run:ui             # Run ui-for-docker container (docker inspect in browser)


# See additional information in Thorfile
```

Before run any containers you should build Passenger image:

```bash
thor d:build:app
```

### Default runtime

As you can see, there are `default-node-app` and `default-ruby-app` directories in this repository.
To launch default runtime for these apps type:

```bash
thor d:build:app
thor d:run:default
```

It will build Passenger image first and then run default containers:
redis, postgres, node\_app, ruby\_app, nginx

You can access dockerized apps via:

```bash
➜  curl http://localhost
#Hello from node app! 

➜  curl http://localhost/api
#Hello from ruby app!
```





