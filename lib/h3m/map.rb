require 'colorize'

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

    def initialize(file, unzipped=false)
      if file.respond_to? :read
        # Consider file argument is IO-like object
        @path = file.path if file.respond_to? :path
        if unzipped
          @file = file
        else
          @gzip_file = file
        end
      else
        # Consider file argument is a file path
        @path = file
        if unzipped
          @file = File.new(path)
        else
          @gzip_file = File.new(path)
        end
      end
    end

    def file
      @file ||= Zlib::GzipReader.new(@gzip_file)
    end

    def record
      @record ||= H3m::MapRecord.read(file)
    rescue IOError => e
      raise H3m::MapError.new("IOError: #{e}")
    rescue RangeError => e
      raise H3m::MapError.new("RangeError: #{e}")
    end

    def name
      record.map_name
    end

    def description
      record.map_desc
    end

    # Get extension 
    # @return [Symbol] :SoD, :AB or :RoE
    def version
      @version ||= case record.heroes_version
        when 0x0E then :RoE
        when 0x15 then :AB
        when 0x1C then :SoD
        else
          raise MapError.new("unknown map version")
      end
    end

    def size
      @size ||= case record.map_size
        when 36  then :S
        when 72  then :M
        when 108 then :L
        when 144 then :XL
        else
          raise MapError.new("unknown map size")
      end
    end

    def difficulty
      @difficulty ||= case record.map_difficulty
        when 0 then :easy
        when 1 then :normal
        when 2 then :hard
        when 3 then :expert
        when 4 then :impossible
        else
          raise MapError.new("unknown map difficulty %x" % record.map_difficulty)
      end
    end

    def has_subterranean?
      unless [0, 1].include? record.map_has_subterranean
        raise MapError.new("unknown value %x for subterranean presence flag" %
                           record.map_has_subterranean)
      end
      record.map_has_subterranean != 0
    end

    def max_level
      record.max_level
    end

    def players
      @players ||= record.players.each_with_index.map do |rec, i|
        Player.new(rec, i)
      end
    end

    def get_colored_sym tile
      case tile.type
        when 0  then "X ".colorize(:light_black)
        when 1  then "X ".colorize(:light_yellow)
        when 2  then "X ".colorize(:light_green)
        when 3  then "X ".colorize(:light_white)
        # 04 - Swamp           (светло-зеленый)    (6F 80 4F)
        # 05 - Rough           (темно-желтый)      (30 70 80)
        # 06 - Subterranean    (красный)           (30 80 00)
        # 07 - Lava            (темно-серый)       (4F 4F 4F)
        when 7  then "X ".colorize(:red)
        when 8  then "X ".colorize(:blue)
        # 09 - Rock            (черный)            (00 00 00)
        else
          (tile.type.to_s + " ").colorize(:cyan)
      end
    end

    def print_map
      # p String.colors

      gr1 = []
      gr2 = []
      _size = record.map_size

      for row in 0.._size-1
        for col in 0.._size-1
          index = row * _size + col

          gr1_tile = record.ground[index]
          gr1[row] ||= ''
          gr1[row] = gr1[row] + get_colored_sym(gr1_tile)

          if has_subterranean?
            gr2_tile = record.underground[index]
            gr2[row] ||= ''
            gr2[row] = gr2[row] + get_colored_sym(gr2_tile)
          end
        end
      end

      for row in 0.._size-1
        puts gr1[row] + (has_subterranean? ? '         ' + gr2[row] : '')
      end

    end
  end

end