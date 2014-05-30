require 'rest_client'
require 'json'

class EightTracksEndpoint

    @@api_key = nil
    @@endpoint = RestClient::Resource.new('http://8tracks.com')
    @@token = nil

    def self.set_api_key k
        @@api_key = k
    end

    def self.api_key
        @@api_key
    end

    # internal method used to access an api resource
    def self.get_json_v3 path
        puts "get #{path}"
        path += (path.include? '?') ? '&' : '?'
        path += "api_key=#{@@api_key}&api_version=3"
        JSON.load(@@endpoint[path].get.to_s)
    end

    # convert the http mix url to its numeric id by regexing over the html
    def self.get_mix_id url
        return RestClient.get(url).to_s[/mixes\/(\d+)[\/\<]/, 1].to_i
    end

    # get the details for the given mix
    def self.get_mix mix_id
        return get_json_v3("mixes/#{mix_id}.json")
    end

    # get a new play token for the EightTracksEndpoint
    def self.refresh_play_token
        @@token = get_json_v3("sets/new.json")['play_token']
    end

    # select mix for playback
    def self.get_start_track mix_id
        refresh_play_token if @@token.nil?
        return get_json_v3("sets/#{@@token}/play.json?mix_id=#{mix_id}")
    end

    # next track
    def self.get_next_track mix_id
        refresh_play_token if @@token.nil?
        return get_json_v3("sets/#{@@token}/next.json?mix_id=#{mix_id}")
    end

    # skip track
    def self.get_skip_track mix_id
        refresh_play_token if @@token.nil?
        return get_json_v3("sets/#{@@token}/skip.json?mix_id=#{mix_id}")
    end

    # report the performance of a track, so that peeps get paid yo!
    def self.report_performance mix_id, track_id
        refresh_play_token if @@token.nil?
        return get_json_v3("sets/#{@@token}/report.json?track_id=#{track_id}&mix_id=#{mix_id}")
    end

end
