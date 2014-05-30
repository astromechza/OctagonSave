
class MissingTrackError < RuntimeError

    def initialize message=nil
        @message = message
    end

    def inspect
        @message
    end

    def to_s
        inspect
    end

    def message
        @message || self.class.name
    end

end