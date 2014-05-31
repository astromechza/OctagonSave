Gem::Specification.new do |s|
    s.name        = 'octagon'
    s.version     = '1.1.0'
    s.date        = '2014-05-31'
    s.summary     = "8tracks downloader."
    s.description = "A quick command line tool for downloading a mix from 8tracks."
    s.authors     = ["Ben Meier"]
    s.email       = 'benmeier42@gmail.com'
    s.files       = ["lib/eight_tracks_endpoint.rb",
                     "lib/exceptions.rb",
                     "lib/mix.rb",
                     "lib/octagon.rb",
                     "lib/track.rb"]
    s.license     = 'MIT'
    s.executables = %w(octagon)
    s.require_paths = ["lib"]
    s.required_ruby_version     = '>= 2.1.0'
    s.homepage = 'http://github.com/AstromechZA/OctagonSave'

    s.add_dependency('ruby-mp3info', '~> 0.8.4')
    s.add_dependency('rest_client', '~> 1.7.3')
    s.add_dependency('rspec', '~> 2.14.1')
    s.add_dependency('log4r', '~> 1.1.10')
end