require 'net/http'

class Downloader

    def initialize(api_key)
        # validate args
        if api_key.nil? or api_key.size != 40
            raise "#{api_key} is an invalid api_key"
        end

        @api_key = api_key
    end

    def save_all(playlist_url, path)
        if playlist_url.nil? or not playlist_url.include? '8tracks.com'
            raise "#{playlist_url.inspect} is an invalid playlist_url"
        end
        @playlist_url = playlist_url



    end
end
