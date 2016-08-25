version_file = File.expand_path('lib/union_station_hooks_core/version_data.rb', File.dirname(__FILE__))
version_data = eval(File.read(version_file))

Gem::Specification.new do |s|
  s.name = "union_station_hooks_core"
  s.version = version_data[:string]
  s.authors = ["Hongli Lai"]
  s.description = "Union Station Ruby hooks core code."
  s.summary = "Union Station Ruby hooks core code"
  s.email = "info@phusion.nl"
  s.license = "MIT"
  s.files = Dir[
    "README.md",
    "LICENSE.md",
    "*.gemspec",
    "lib/**/*"
  ]
  s.homepage = "https://github.com/phusion/union_station_hooks_core"
  s.require_paths = ["lib"]

  # DO NOT ADD ANY FURTHER DEPENDENCIES! See hacking/Vendoring.md,
  # section "No dependencies", for more information.
end
