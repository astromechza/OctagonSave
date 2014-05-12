Gem::Specification.new do |s|
    s.name        = 'octagon'
    s.version     = '1.0.0'
    s.date        = '2014-05-12'
    s.summary     = "8tracks downloader."
    s.description = "A quick command line tool for downloading a mix from 8tracks."
    s.authors     = ["Ben Meier"]
    s.email       = 'benmeier42@gmail.com'
    s.files       = ["lib/octagon.rb"]
    s.license     = 'MIT'
    s.executables = %w(octagon)
    s.require_paths = ["lib"]
    s.required_ruby_version     = '>= 2.1.0'
end