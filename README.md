# Octagon
A Ruby gem for downloading playlists from 8tracks. Octagon aims to use the 8tracks api to correctly download tracks in a mostly (but not very) legal manner ;)

Build for Ruby 2.1.0

### Installation
Unfortunately I'm not putting this on rubygems.org. So for now you need to clone, build, and install.

    $ git clone git://github.com/AstromechZA/OctagonSave.git
    $ cd OctagonSave
    $ gem build octagon.gemspec
    $ gem install octagon-x.x.x.gem              # where x.x.x is the version number

## Usage

    require 'octagon'

    # create downloader using some valid 40 character api key
    o = OctagonDownloader.new( '1234567890abcdef1234567890abcdef12345678' )
    
    # download a playlist to a directory
    o.save_all( 'http://8tracks.com/someuser/somemix', '~/Music' )

### or use the command line tool!
    $ octagon configure 1234567890abcdef1234567890abcdef12345678
    $ octagon get http://8tracks.com/someuser/somemix ~/Music
