require 'json'
require 'tempfile'
require 'openssl'
require 'mp3info'
require 'yaml'
require 'rest_client'

class Downloader

    def initialize(api_key)
        # validate args
        if api_key.nil? or api_key.size != 40
            raise "#{api_key.inspect} is an invalid api_key"
        end

        @eightTracks = RestClient::Resource.new('http://8tracks.com')
        @api_key = api_key
        @token = get_play_token()
        puts "token #{@token}"
    end

    def save_all(playlist_url, path)
        playlist_url, output_dir = sanitize_save_params( playlist_url, path )

        puts "retrieving playlist id"
        playlist_id = get_playlist_id( playlist_url )
        puts "playlist id = #{playlist_id}"

        if playlist_id.nil?
            raise "Invalid 8tracks url"
        end
        puts "retrieving playlist loader"
        loader = get_playlist_loader( playlist_id )

        puts "retrieving playlist info"
        info = get_playlist_info( playlist_id )

        album_name = sanitize_filename(info['mix']['name'])
        album_genre = info['mix']['genres'][0..3].join(';')

        output_dir = File.join(output_dir, album_name)

        unless Dir.exists? output_dir
            Dir.mkdir output_dir
            puts "Created output directory (#{output_dir})"
        end

        song_number = 1
        while true
            curr_song_url = loader['set']['track']['url']
            curr_song_artist = loader['set']['track']['performer']
            curr_song_title = loader['set']['track']['name']
            curr_track_id = loader['set']['track']['id']
            curr_song_duration = loader['set']['track']['play_duration']
            puts loader['set'].inspect

            puts "get real url for #{curr_song_url}"
            actual_url = get_song_stream_url( curr_song_url )
            unless actual_url.nil?
                puts "got #{actual_url}"

                parsed_url = URI(actual_url)

                filetype = parsed_url.path[-3..-1]

                file_name = "#{song_number} - #{curr_song_artist} - #{curr_song_title}.#{filetype}"

                file_name = sanitize_filename(file_name)

                file_path = File.join(output_dir, file_name)

                puts "built file path #{file_path}"

                start_time = Time.now.to_i

                http = Net::HTTP.new(parsed_url.host, parsed_url.port)
                if parsed_url.scheme.downcase == 'https'
                    http.use_ssl = true
                    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
                end

                http.request_get(parsed_url.path + '?' + parsed_url.query) do |response|
                    if response.is_a? Net::HTTPOK
                        temp_file = Tempfile.new(file_name)
                        temp_file.binmode

                        size = 0
                        progress = 0
                        total = response.header["Content-Length"].to_i

                        response.read_body do |chunk|
                            temp_file << chunk
                            size += chunk.size
                            new_progress = (size * 100) / total
                            unless new_progress == progress
                                puts "\rDownloading %s (%3d%%) " % [file_name, new_progress]
                            end
                            progress = new_progress
                        end

                        temp_file.close

                        puts "adding ID3 tags"
                        begin
                            Mp3Info.open(temp_file.path) do |mp3|
                                mp3.tag.title = curr_song_title
                                mp3.tag.artist = curr_song_artist
                                mp3.tag.album = info['mix']['name']
                                mp3.tag.tracknum = song_number
                                mp3.tag.genre_s = album_genre
                            end
                        rescue Exception => e
                            puts e
                        end

                        puts "move file to target"
                        FileUtils.mv temp_file.path, file_path, :force => true
                        puts "complete"

                    else
                        puts response
                    end
                end

                delay = Time.now.to_i - (start_time + 30)
                sleep(-delay) if delay < 0

                report_performance(playlist_id, curr_track_id)

                delay = Time.now.to_i - (start_time + curr_song_duration)
                #sleep(-delay) if delay < 0



            end

            song_number += 1

            loader = iterate_loader( playlist_id )
            return if loader['set']['at_end']
        end

    end

    private

        def sanitize_save_params(playlist_url, path)
            # validate playlist_url
            if playlist_url.nil? or not playlist_url.include? '8tracks.com'
                raise "#{playlist_url.inspect} is not a valid 8tracks playlist_url"
            end

            # set output path
            if path.nil? or path.empty?
                raise "#{path.inspect} is not a valid output path"
            end

            return playlist_url, File.expand_path(path)
        end

        def get_play_token
            r = @eightTracks["sets/new.json?api_key=#{@api_key}"].get().to_str
            raise r if r == 'You must use a valid API key.'
            jsn = JSON.load(r)
            return jsn['play_token']
        end

        def get_playlist_id(playlist_url)
            content = RestClient.get playlist_url
            return content.to_str[/mixes\/(\d+)\/player/, 1]
        end

        def get_playlist_loader(playlist_id)
            r = @eightTracks["sets/#{@token}/play.json?mix_id=#{playlist_id}&api_key=#{@api_key}"].get
            return JSON.load(r.to_str)
        end

        def get_playlist_info(playlist_id)
            r = @eightTracks["mixes/#{playlist_id}.json?api_key=#{@api_key}"].get
            return JSON.load(r.to_str)
        end

        def get_song_stream_url(url)
            RestClient.get url do |response, request, result, &block|
                if [301, 302, 307].include? response.code
                    return response.headers[:location]
                end
            end
            return nil
        end

        def report_performance(playlist_id, track_id)
            @eightTracks["sets/#{@token}/report.xml?track_id=#{track_id}&mix_id=#{playlist_id}&api_key=#{@api_key}"].get
        end

        def iterate_loader(playlist_id)
            resource = "sets/#{@token}/next.json?mix_id=#{playlist_id}&api_key=#{@api_key}"
            r = @eightTracks[resource].get

            while r.code == '403'
                puts "8tracks throttling! D:"
                sleep(30)
                r = @eightTracks[resource].get
            end

            puts r.to_str

            return JSON.load(r.to_str)
        end

        def sanitize_filename(fn)
            return fn.gsub(/[^a-z0-9\-_\.\(\) ]+/i, '_')
        end
end

if __FILE__ == $0

    # setup proxy
    RestClient.proxy = ENV['http_proxy'] if ENV['http_proxy']

    # has a command been specified
    if ARGV.size >= 1
        case ARGV[0]
        when 'configure'
            if ARGV.size == 2
                k = ARGV[1]
                begin
                    test = Downloader.new(k)
                    puts "Configuring OctagonSave with new api key #{k}"
                    target = File.join(Dir.home, '.octagon_save', 'config.yml')
                    config = {'api_key' => k}
                    FileUtils.mkdir_p File.dirname target
                    File.open(target, 'w') {|f| f.write config.to_yaml}
                rescue Exception => e
                    puts "An error occured while testing the new key: #{e.message}"
                end
            else
                puts "usage: downloader.rb configure <8tracks api key>"
            end
        when 'get'
            if ARGV.size == 3
                url = ARGV[1]
                output_dir = ARGV[2]
                api_key = nil
                begin
                    target = File.join(Dir.home, '.octagon_save', 'config.yml')
                    config = YAML::load_file(target)
                    api_key = config['api_key']
                rescue Exception => e
                    puts "An error occured while loading configuration: #{e.message}"
                end

                Downloader.new(api_key).save_all(url, output_dir)

            else
                puts "usage: downloader.rb get <8tracks mix url> <output directory>"
            end
        else
            puts "command #{ARGV[0].inspect} is unknown"
            puts "usage: downloader.rb <configure|get>"
        end
    else
        puts "usage: downloader.rb <configure|get>"
    end
end