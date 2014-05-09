require 'net/http'
require 'json'

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
            puts "Created output directory (#{@output_dir})"
        end

        playlist_id = get_playlist_id( playlist_url )

        if playlist_id.nil?
            raise "Invalid 8tracks url"
        end

        loader = get_playlist_loader( playlist_id )
        info = get_playlist_info( playlist_id )



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
            playlist = URI("http://8tracks.com/mixes/#{playlist_id}.json&api_key=#{@api_key}")
            return JSON.load(Net::HTTP.get(playlist))
        end
end