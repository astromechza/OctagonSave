require 'rest_client'
require_relative 'exceptions'

class Track

    attr_reader :id
    attr_reader :stream
    attr_reader :title
    attr_reader :artist
    attr_reader :album
    attr_reader :year
    attr_reader :genres
    attr_reader :number
    attr_reader :filetype
    attr_reader :filename

    def initialize params
        @id = params['id']
        @stream = params['track_file_stream_url']
        @title = params['name']
        @artist = params['performer']
        @album = params['release_name']
        @year = params['year']
        @genres = params['genres']
        @number = params['number']

        check_url_redirect

        @filetype = URI(@stream).path[-3..-1]
        @filename = create_filename
    end

    private

        def check_url_redirect
            RestClient.head @stream do |response, request, result, &block|
                case response.code
                when 301, 302, 307
                    @stream = response.headers[:location]
                when 404
                    raise MissingTrackError.new 'Track missing'
                end
            end
        end

        def create_filename
            return "#{@number} - #{@artist} - #{@title}.#{@filetype}"
        end

end
