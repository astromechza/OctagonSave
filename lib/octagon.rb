require 'json'
require 'tempfile'
require 'openssl'
require 'mp3info'
require 'yaml'
require 'rest_client'
require 'log4r'
include Log4r

class OctagonDownloader

    def initialize(api_key)
        @log = Log4r::Logger.new('octagon')
        @log.level = INFO
        @log.outputters = Outputter.stdout
        @log.outputters.first.formatter = PatternFormatter.new(:pattern => "[%l] %d :: %m")

        # validate args
        if api_key.nil? or api_key.size != 40
            raise "#{api_key.inspect} is an invalid api_key"
        end

        @eightTracks = RestClient::Resource.new('http://8tracks.com')
        @api_key = api_key
        @token = get_play_token()
        @log.info "Play token acquired: #{@token}"
    end

    def save_all(playlist_url, path)
        playlist_url, output_dir = sanitize_save_params( playlist_url, path )

        @log.info "Retrieving mix id for #{playlist_url}.."
        playlist_id = get_playlist_id( playlist_url )

        @log.debug "Mix id = #{playlist_id}"
        if playlist_id.nil?
            raise "Invalid 8tracks url"
        end
        @log.info "Retrieving mix loader.."
        loader = get_playlist_loader( playlist_id )

        @log.info "Retrieving mix info.."
        info = get_playlist_info( playlist_id )

        @log.debug info

        @log.info "Mix title = #{info['mix']['name']}"
        @log.info "Mix genres = #{info['mix']['genres'].join(', ')}"
        @log.info "Mix track count = #{info['mix']['tracks_count']}"
        album_name = sanitize_dirname(info['mix']['name'])
        album_genre = info['mix']['genres'][0..3].join(';')
        album_length = info['mix']['tracks_count']

        output_dir = File.join(output_dir, album_name)
        unless Dir.exists? output_dir
            @log.info "Building output directory #{output_dir}"
            FileUtils.mkdir_p File.dirname output_dir
        end

        song_number = 1
        while true
            @log.info "Track #{song_number}/#{album_length}"

            curr_song_url = loader['set']['track']['url']
            curr_song_artist = loader['set']['track']['performer']
            curr_song_title = loader['set']['track']['name']
            curr_track_id = loader['set']['track']['id']
            curr_song_duration = loader['set']['track']['play_duration']

            @log.debug loader['set'].inspect

            @log.debug "get real url for #{curr_song_url}"
            actual_url = get_song_stream_url( curr_song_url )
            unless actual_url.nil?

                parsed_url = URI(actual_url)

                @log.info "Got #{parsed_url.path}"

                filetype = parsed_url.path[-3..-1]

                file_name = "#{song_number} - #{curr_song_artist} - #{curr_song_title}.#{filetype}"

                file_name = sanitize_filename(file_name)

                file_path = File.join(output_dir, file_name)

                @log.debug "built file path #{file_path}"

                start_time = Time.now.to_i

                @log.info "Beginning download to #{file_name}"

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
                                @log.debug "\rDownloading %s (%3d%%) " % [file_name, new_progress]
                            end
                            progress = new_progress
                        end

                        temp_file.close

                        @log.info "Adding ID3 tags"
                        begin
                            Mp3Info.open(temp_file.path) do |mp3|
                                mp3.tag.title = curr_song_title
                                mp3.tag.artist = curr_song_artist
                                mp3.tag.album = info['mix']['name']
                                mp3.tag.tracknum = song_number
                                mp3.tag.genre_s = album_genre
                            end
                        rescue Exception => e
                            @log.error e
                        end

                        @log.info "Move file to output directory"
                        FileUtils.mv temp_file.path, file_path, :force => true
                        @log.info "Complete"

                    else
                        @log.error response
                    end
                end

                delay = Time.now.to_i - (start_time + 30)
                if delay < 0
                    @log.info "Waiting for 30 second point for play report..."
                    sleep(-delay)
                end
                @log.info "Sending performance report to 8tracks."
                report_performance(playlist_id, curr_track_id)

                #delay = Time.now.to_i - (start_time + curr_song_duration)
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
            r = nil
            while true
                begin
                    r = @eightTracks[resource].get
                    @log.debug r.to_str
                    return JSON.load(r.to_str)
                rescue => e
                    if e.response.code == 403
                        @log.warn "8tracks throttling! :( [wait 30s]"
                        sleep(30)
                    else
                        return nil
                    end
                end
            end
        end

        def sanitize_filename(fn)
            return fn.gsub(/[^a-z0-9\-_\.\(\) ]+/i, '_')
        end

        def sanitize_dirname(fn)
            return fn.gsub(/[^a-z0-9\-_\(\)\[\] ]+/i, '_')
        end
end
