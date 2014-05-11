require 'net/http'
require 'json'
require 'tempfile'

class Downloader

    def initialize(api_key)
        # validate args
        if api_key.nil? or api_key.size != 40
            raise "#{api_key.inspect} is an invalid api_key"
        end

        @api_key = api_key
        @token = get_play_token()
    end

    def save_all(playlist_url, path)
        playlist_url, output_dir = sanitize_save_params( playlist_url, path )

        unless Dir.exists? output_dir
            Dir.mkdir output_dir
            puts "Created output directory (#{output_dir})"
        end

        playlist_id = get_playlist_id( playlist_url )

        if playlist_id.nil?
            raise "Invalid 8tracks url"
        end

        loader = get_playlist_loader( playlist_id )
        info = get_playlist_info( playlist_id )

        at_end = false
        song_number = 1
        m3u = []
        while not at_end
            curr_song_url = loader['set']['track']['track_file_stream_url']
            curr_artist = loader['set']['track']['performer']
            curr_song_title = loader['set']['track']['name']
            curr_album = loader['set']['track']['release_name']

            uri = URI(curr_song_url)
            resp = Net::HTTP.get_response(uri)

            actual_url = resp['location']
            parsed_url = URI(actual_url)

            filetype = parsed_url.path[-3..-1]

            file_name = "#{song_number} - #{curr_artist} - #{curr_song_title}.#{filetype}"

            file_name = sanitize_filename(file_name)

            file_path = File.join('.', file_name)

            unless File.exists? (file_path)

                http = Net::HTTP.new(parsed_url.host, parsed_url.port)
                if parsed_url.scheme.downcase == 'https'
                    http.use_ssl = true
                    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
                end

                http.request_get(parsed_url.path + '?' + parsed_url.query) do |response|
                    if response.is_a? Net::HTTPOK
                        temp_file = Tempfile.new("#{file_name}.part")
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
                        FileUtils.mkdir_p File.dirname(file_path)
                        FileUtils.mv temp_file.path, file_path, :force => true

                    else
                        puts response
                    end
                end

            else
                puts "Song #{file_path.inspect} already exists. Skipping."
            end

            puts file_name


            return false
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
            jsn = JSON.load(Net::HTTP.get('8tracks.com', "/sets/new.json?api_key=#{@api_key}"))
            return jsn['play_token']
        end

        def get_playlist_id(url)
            content = Net::HTTP.get(URI(url))
            return content[/mixes\/(\d+)\/player/, 1]
        end

        def get_playlist_loader(playlist_id)
            playurl = URI("http://8tracks.com/sets/#{@token}/play?mix_id=#{playlist_id}&format=jsonh&api_key=#{@api_key}")
            return JSON.load(Net::HTTP.get(playurl))
        end

        def get_playlist_info(playlist_id)
            playlist = URI("http://8tracks.com/mixes/#{playlist_id}.json?api_key=#{@api_key}")
            return JSON.load(Net::HTTP.get(playlist))
        end

        def sanitize_filename(fn)
            return fn.gsub(/[^a-z0-9\-_\.\(\) ]+/i, '_')
        end
end