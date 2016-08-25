version_file = File.expand_path('lib/union_station_hooks_rails/version_data.rb', File.dirname(__FILE__))
version_data = eval(File.read(version_file))

Gem::Specification.new do |s|
  s.name = "union_station_hooks_rails"
  s.version = version_data[:string]
  s.authors = ["Hongli Lai"]
  s.description = "Union Station Rails hooks."
  s.summary = "Union Station Rails hooks"
  s.email = "info@phusion.nl"
  s.license = "MIT"
  s.files = Dir[
    "README.md",
    "LICENSE.md",
    "*.gemspec",
    "lib/**/*"
  ]
  s.homepage = "https://github.com/phusion/union_station_hooks_rails"
  s.require_paths = ["lib"]

  # If you update the dependency version here, also update
  # the version in Gemfile and union_station_hooks_rails.rb method
  # `require_and_check_union_station_hooks_core`
  s.add_dependency("union_station_hooks_core", "~> 2.0.4")

  s.add_dependency("activesupport", ">= 3.0")
  s.add_dependency("activemodel", ">= 3.0")
  s.add_dependency("actionpack", ">= 3.0")
  s.add_dependency("railties", ">= 3.0")

  # DO NOT ADD ANY FURTHER DEPENDENCIES! See
  # https://github.com/phusion/union_station_hooks_core/blob/master/hacking/Vendoring.md,
  # section "No dependencies", for more information.
end
