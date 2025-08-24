require_relative 'lib/version'

Gem::Specification.new do |s|
  s.name        = 'musalce-server'
  s.version     = MusaLCEServer::VERSION
  s.date        = '2025-08-23'
  s.summary     = 'A Musa DSL live coding environment for Ableton Live 11 and Bitwig Studio 5'
  s.description = 'This package implements the Server part of the Musa DSL Live Coding Environment for Ableton Live and Bitwig Studio'
  s.authors     = ['Javier Sánchez Yeste']
  s.email       = 'javier.sy@gmail.com'
  s.executables = ['musalce-server']
  s.files       = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features|samples)/}) }
  s.homepage    = 'https://github.com/javier-sy/musalce-server'
  s.license     = 'GPL-3.0-or-later'

  s.required_ruby_version = '>= 2.7'

  # TODO
  #s.metadata    = {
    # "source_code_uri" => "https://",
    # "homepage_uri" => "",
    # "documentation_uri" => "",
    # "changelog_uri" => ""
  #}

  s.add_runtime_dependency 'musa-dsl', '~> 0', '>= 0.26.0'

  s.add_runtime_dependency 'midi-communications', '~> 0.6'
  s.add_runtime_dependency 'midi-events', '~> 0.6'
  s.add_runtime_dependency 'midi-parser', '~> 0.4'

  #s.add_runtime_dependency 'eventmachine', '~> 1.2', '>= 1.2.7'
  s.add_runtime_dependency 'osc-ruby', '~> 1.1', '>= 1.1.5'
end
