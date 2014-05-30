require 'rest_client'
require 'tempfile'

require_relative 'eight_tracks_endpoint'
require_relative 'mix'
require_relative 'exceptions'

class OctagonDownloader

    def initialize(api_key)

        if api_key.nil? or api_key.size != 40
            raise "#{api_key.inspect} is an invalid api_key"
        end

        EightTracksEndpoint.set_api_key api_key
    end

    def save_all(mix_url, output_dir)
        m = Mix.new mix_url

        while m.has_next?
            begin
                t = m.next

                start_time = Time.now.to_i

                # download track
                f = download t

                # tag track
                if t.filetype == 'mp3'
                    # tag(f, t) # todo
                end

                FileUtils.mv f, File.join(output_dir, t.filename)

                delay = start_time + 30 - Time.now.to_i
                sleep(delay) if delay > 0

                EightTracksEndpoint.report_performance(m.id, t.id)

            rescue RestClient::Forbidden
                sleep(30)
            rescue MissingTrackError => e
                puts e.class
            end
        end
    end

    private

        def download track
            temp_file = Tempfile.new(track.filename)
            temp_file.binmode

            chunker = lambda do |response|

                size = 0
                progress = 0
                total = response.header["Content-Length"].to_i

                response.read_body do |chunk|
                    temp_file << chunk
                    size += chunk.size
                    new_progress = (size * 100) / total
                    unless new_progress == progress
                        puts new_progress
                    end
                end

            end

            RestClient::Request.execute(:method => :get, :url => track.stream, :block_response => chunker)

            temp_file.close
            return temp_file.path
        end

end
