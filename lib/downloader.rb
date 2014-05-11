require 'net/http'
require 'json'
require 'tempfile'
require 'openssl'
require 'mp3info'

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

        playlist_id = get_playlist_id( playlist_url )

        if playlist_id.nil?
            raise "Invalid 8tracks url"
        end

        loader = get_playlist_loader( playlist_id )
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
            puts loader['set'].inspect

            puts "get real url for #{curr_song_url}"
            uri = URI(curr_song_url)
            resp = Net::HTTP.get_response(uri)
            if [200, 302].include? resp.code.to_i
                actual_url = resp['location']
                puts "got #{resp.code} #{actual_url}"

                parsed_url = URI(actual_url)

                filetype = parsed_url.path[-3..-1]

                file_name = "#{song_number} - #{curr_song_artist} - #{curr_song_title}.#{filetype}"

                file_name = sanitize_filename(file_name)

                file_path = File.join(output_dir, file_name)

                puts "built file path #{file_path}"


                http = Net::HTTP.new(parsed_url.host, parsed_url.port)
                if parsed_url.scheme.downcase == 'https'
                    http.use_ssl = true
                    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
                end

                start_time = Time.now.to_i

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
            jsn = JSON.load(Net::HTTP.get('8tracks.com', "/sets/new.json?api_key=#{@api_key}"))
            return jsn['play_token']
        end

        def get_playlist_id(url)
            content = Net::HTTP.get(URI(url))
            return content[/mixes\/(\d+)\/player/, 1]
        end

        def get_playlist_loader(playlist_id)
            playurl = URI("http://8tracks.com/sets/#{@token}/play.json?mix_id=#{playlist_id}&api_key=#{@api_key}")
            return JSON.load(Net::HTTP.get(playurl))
        end

        def get_playlist_info(playlist_id)
            playlist = URI("http://8tracks.com/mixes/#{playlist_id}.json?api_key=#{@api_key}")
            return JSON.load(Net::HTTP.get(playlist))
        end

        def report_performance(playlist_id, track_id)
            return Net::HTTP.get(URI("http://8tracks.com/sets/#{@token}/report.json?track_id=#{track_id}&mix_id=#{playlist_id}"))
        end

        def iterate_loader(playlist_id)
            playurl = URI("http://8tracks.com/sets/#{@token}/next.json?mix_id=#{playlist_id}&api_key=#{@api_key}")

            res = Net::HTTP.get_response(playurl)

            while res.code == '403'
                puts "8tracks throttling! D:"
                sleep(30)
                res = Net::HTTP.get_response(playurl)
            end

            puts res.body

            return JSON.load(res.body)
        end

        def sanitize_filename(fn)
            return fn.gsub(/[^a-z0-9\-_\.\(\) ]+/i, '_')
        end
end