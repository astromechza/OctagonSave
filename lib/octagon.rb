require 'rest_client'
require 'tempfile'
require 'mp3info'

require_relative 'eight_tracks_endpoint'
require_relative 'mix'
require_relative 'exceptions'

class OctagonDownloader

    def initialize api_key

        if api_key.nil? or api_key.size != 40
            raise "#{api_key.inspect} is an invalid api_key"
        end

        EightTracksEndpoint.set_api_key api_key
    end

    def save_all mix_url, output_dir
        m = Mix.new mix_url

        output_dir = File.join(File.expand_path(output_dir), sanitize_dirname(m.name))

        unless Dir.exists? output_dir
            FileUtils.mkdir_p output_dir
        end

        while m.has_next?
            begin
                t = m.next

                start_time = Time.now.to_i

                # download track
                f = download t

                # tag track
                if t.filetype == 'mp3'
                    tag(f, t)
                end

                FileUtils.mv f, File.join(output_dir, sanitize_filename(t.filename))

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
            temp_file = Tempfile.new(sanitize_filename(track.filename))
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

        def tag file, track
            begin
                Mp3Info.open(file) do |mp3|
                    mp3.tag.title = track.title.force_encoding("utf-8")
                    mp3.tag.artist = track.artist.force_encoding("utf-8")
                    mp3.tag.album = track.album.force_encoding("utf-8")
                    mp3.tag.tracknum = track.number
                    mp3.tag.year = track.year.to_i
                    mp3.tag.genre_s = track.genres[0..3].join(';').force_encoding("utf-8")
                end
            rescue Exception => e
                puts e
            end
        end

        def sanitize_filename input
            input.gsub(/[^\w `#`~!@''\$%&\(\)_\-\+=\[\]\{\};,\.]/i, '_')
        end

        def sanitize_dirname input
            input.gsub(/[^\w `#`~!@''\$%&\(\)_\-\+=\[\]\{\};,\.]/i, '_')
        end

end
