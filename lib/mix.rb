require 'rest_client'
require_relative 'eight_tracks_endpoint'
require_relative 'track'

class Mix

    def initialize(mix_url)
        # basic check for 8tracks url
        if mix_url.nil? or not mix_url.include? '8tracks.com'
            raise "'#{mix_url}' is not a valid 8tracks mix url."
        end

        @url = mix_url

        @id = EightTracksEndpoint.get_mix_id @url
        @info = EightTracksEndpoint.get_mix @id

        @current_loader = nil
        @current_track_num = 0
    end

    def id
        @id
    end

    def info
        @info
    end

    def has_next?
        if @current_loader.nil?
            return true
        end
        return (not (@current_loader['set']['at_last_track'] || @current_loader['set']['at_end']))
    end

    def next
        if @current_loader.nil?
            @current_loader = EightTracksEndpoint.get_start_track @id
        else
            @current_loader = EightTracksEndpoint.get_next_track @id
        end

        @current_track_num += 1
        @current_loader['set']['track']['number'] = @current_track_num
        @current_loader['set']['track']['genres'] = @info['mix']['genres']

        return Track.new @current_loader['set']['track']
    end

end
