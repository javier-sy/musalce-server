Gem::Specification.new do |s|
  s.name        = 'MusaLCEforLive-Server'
  s.version     = '0.2.0'
  s.date        = '2021-11-19'
  s.summary     = 'A Musa DSL live coding environment for Ableton Live 11'
  s.description = 'This package implements the Server part of the Musa DSL Live Coding Environment for Live'
  s.authors     = ['Javier Sánchez Yeste']
  s.email       = 'javier.sy@gmail.com'
  s.files       = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features|samples)/}) }
  s.homepage    = 'https://github.com/javier-sy/MusaLCEforLive_Server'
  s.license     = 'GPL-3.0'

  s.required_ruby_version = '~> 2.7'

  # TODO
  #s.metadata    = {
    # "source_code_uri" => "https://",
    # "homepage_uri" => "",
    # "documentation_uri" => "",
    # "changelog_uri" => ""
  #}

  s.add_runtime_dependency 'musa-dsl', '~> 0.26', '>= 0.26.0'

  s.add_runtime_dependency 'midi-communications', '~> 0.5', '>= 0.5.1'
  s.add_runtime_dependency 'midi-events', '~> 0.5', '>= 0.5.0'
  s.add_runtime_dependency 'midi-parser', '~> 0.3', '>= 0.3.0'

  s.add_runtime_dependency 'eventmachine', '~> 1.2', '>= 1.2.7'
  s.add_runtime_dependency 'osc-ruby', '~> 1.1', '>= 1.1.4'
end
