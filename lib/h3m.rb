require "h3m/version"
require "h3m/record"
require "zlib"

module H3m

  class MapError < StandardError
  end
  
  class Map
    # Map representation
    #
    # Example:
    #   >> map = H3m::Map.new("some-map-file.h3m")
    #   >> map.version
    #   => :SoD

    attr_reader :path

    def initialize(path)
      @path = path
      @gzip_file = File.new(path)
    end

    def file
      @file ||= Zlib::GzipReader.new(@gzip_file)
    end

    # Get extension 
    # @return [Symbol] :SoD, :AB or :RoE
    def version
      @version ||= case record.heroes_version
        when 0x0E then :RoE
        when 0x15 then :AB
        when 0x1C then :SoD
        else
          raise MapError, "unknown map version"
      end
    end

    def size
      @size ||= case record.map_size
        when 36  then :S
        when 72  then :M
        when 108 then :L
        when 144 then :XL
        else
          raise MapError, "unknown map size"
      end
    end

    def record
      @record ||= H3m::Record.read(file)
    end
  end

end
