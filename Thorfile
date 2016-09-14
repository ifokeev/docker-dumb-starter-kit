module D
  CWD = File.dirname(__FILE__)

  def self.expand_path(path) 
    Pathname.new(CWD) + Pathname.new(path)
  end

  class Build < Thor
    desc "app", "Build an app image from app-image folder"
    def app
      system %{ docker build -t app-image -f app-image/Dockerfile app-image }
    end
  end

  class Run < Thor
    desc "ui", "Run ui-for-docker container (docker inspect in browser)"
    def ui
      system %{
        docker run -d --name ui -p 9000:9000 --privileged -v /var/run/docker.sock:/var/run/docker.sock uifd/ui-for-docker
      }
    end

    desc "redis", "Run redis container"
    def redis
      system %{
        docker run -d --name redis -v redis-data:/data redis
      }
    end

    desc "mongo", "Run mongodb container"
    def mongo
      system %{
        docker run -d --name mongo -v mongo-data:/data/db -v mongo-configdb:/data/configdb mongo
      }
    end

    desc "postgres", "Run PostgreSQL container"
    def postgres
      system %{
        docker run -d --name postgres -v postgres-data:/var/lib/postgresql/data postgres
      }
    end

    desc "node_app", "Run Node App container based on app-image image"
    method_option :name, aliases: "-n", desc: "Name of the container", default: "default-node-app"
    method_option :linked, aliases: "-l", desc: "Array of linked containers", type: :array, default: []
    method_option :mount, aliases: "-m", desc: "Mount path (relative or absolute) for the container", default: "default-node-app"
    def node_app
      links = options[:linked].collect { |v| "--link " + v }
      name = options[:name]

      mount_path = D::expand_path(options[:mount])

      system %{
        docker run -d --name #{name}
        -v #{mount_path}:/usr/src/app
        #{links.join(' ')}
        app-image
      }.gsub(/\s+/, " ").strip
    end

    desc "ruby_app", "Run Ruby App container based on app-image image"
    method_option :name, aliases: "-n", desc: "Name of the container", default: "default-ruby-app"
    method_option :linked, aliases: "-l", desc: "Array of linked containers", type: :array, default: ["redis", "postgres:db"]
    method_option :mount, aliases: "-m", desc: "Mount path (relative or absolute) for the container", default: "default-node-app"
    def ruby_app
      links = options[:linked].collect { |v| "--link " + v }

      mount_path = D::expand_path(options[:mount])

      system %{
        docker run -d --name #{options[:name]}
        -v #{mount_path}:/usr/src/app
        #{links.join(' ')}
        app-image
      }.gsub(/\s+/, " ").strip
    end

    desc "sidekiq", "Run sidekiq based on Ruby App and app-image image"
    method_option :name, aliases: "-n", desc: "Name of the container", default: "sidekiq"
    method_option :linked, aliases: "-l", desc: "Array of linked containers", type: :array, default: ["redis"]
    method_option :mount, aliases: "-m", desc: "Mount path (relative or absolute) for the container", default: "default-sidekiq-app"
    method_option :env, aliases: "-e", desc: "Environment", default: "production"
    def sidekiq
      links = options[:linked].collect { |v| "--link " + v }

      mount_path = D::expand_path(options[:mount])

      system %{
        docker run -d --name #{options[:name]}
        -v #{mount_path}:/usr/src/app
        #{links.join(' ')}
        app-image
        bundle exec sidekiq -e#{options[:env]} -C config/sidekiq.yml -d
      }.gsub(/\s+/, " ").strip
    end

    desc "nginx", "Run Nginx container"
    method_option :name, aliases: "-n", desc: "Name of nginx container", default: "nginx"
    method_option :linked, aliases: "-l", desc: "Array of linked containers", type: :array, default: ['default-ruby-app:ruby-app', 'default-node-app:node-app']
    def nginx
      links = options[:linked].collect { |v| "--link " + v }

      system %{
        docker run -d --name #{options[:name]}
        -v #{CWD}/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
        -v #{CWD}/nginx/usr:/usr/src/nginx
        -p 80:8080
        -p 443:8443
        #{links.join(' ')}
        nginx
      }.gsub(/\s+/, " ").strip
    end

    desc "default", "Run default runtime for Node App and Ruby app"
    def default
      invoke :redis
      invoke :postgres
      invoke :node_app
      invoke :ruby_app
      invoke :nginx
    end
  end

  class Exec < Thor
    desc "sh CONTAINER", "system shell on container"
    def sh(container_id)
      system %{
        docker exec -it #{container_id} sh
      }
    end
  end

  class Rm < Thor
    desc "containers", "Stop and remove all created containers"
    def containers
      [:stop, :rm].each do |command|
        ['sidekiq', 'mongo', 'redis', 'postgres', 'default-node-app', 'default-ruby-app', 'nginx'].each do |container|
          system %{
            docker #{command} #{container}
          }
        end
      end
    end
  end
end
