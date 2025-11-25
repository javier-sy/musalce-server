require_relative 'lib/version'

Gem::Specification.new do |s|
  s.name        = 'musalce-server'
  s.version     = MusaLCEServer::VERSION
  s.date        = '2025-11-25'
  s.summary     = 'A Musa DSL live coding environment for Ableton Live 11 and Bitwig Studio 5'
  s.description = 'This package implements the Server part of the Musa DSL Live Coding Environment for Ableton Live and Bitwig Studio'
  s.authors     = ['Javier Sánchez Yeste']
  s.email       = 'javier.sy@gmail.com'
  s.executables = ['musalce-server']
  s.files       = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features|samples)/}) }
  s.homepage    = 'https://github.com/javier-sy/musalce-server'
  s.license     = 'GPL-3.0-or-later'

  s.required_ruby_version = '>= 2.7'

  s.metadata = {
    'homepage_uri' => s.homepage,
    'source_code_uri' => s.homepage,
    'documentation_uri' => 'https://www.rubydoc.info/gems/musalce-server'
  }

  s.add_runtime_dependency 'musa-dsl', '~> 0.40'

  s.add_runtime_dependency 'midi-communications', '~> 0.7'
  s.add_runtime_dependency 'midi-events', '~> 0.7'
  s.add_runtime_dependency 'midi-parser', '~> 0.5'

  s.add_runtime_dependency 'osc-ruby', '~> 1.1', '>= 1.1.5'

  s.add_development_dependency 'minitest', '~> 5', '>= 5.14.4'
  s.add_development_dependency 'rake', '~> 13', '>= 13.0.6'
  s.add_development_dependency 'shoulda-context', '~> 2', '>= 2.0.0'

  s.add_development_dependency 'yard', '~> 0.9'
  s.add_development_dependency 'redcarpet', '~> 3.6'
  s.add_development_dependency 'webrick', '~> 1.8'
end
