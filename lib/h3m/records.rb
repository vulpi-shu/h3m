require 'bindata'

module H3m

  class HeroRecord < BinData::Record
    endian :little

    uint8  :type
    uint32 :name_size
    string :name, read_length: :name_size
  end

  class PlayerRecord < BinData::Record
    endian :little

    uint8 :can_be_human
    uint8 :can_be_computer

    array :offset1, :type => 'uint8', initial_length: :skip_for_version, onlyif: :if_nobody_can_play

    def skip_for_version
      case parent.parent.heroes_version
        when 0x1C then 13 # SOD + WOG
        when 0x15 then 12 # AB
        when 0x0E then 6  # ROE
        else 13
      end
    end

    def if_nobody_can_play
      !(can_be_human > 0 || can_be_computer > 0)
    end

    def if_can_play
      (can_be_human > 0 || can_be_computer > 0)
    end

    struct :info, onlyif: :if_can_play do

      uint8 :ai_tactic

      uint8 :p7,                            onlyif: :if_sod_version # WTF?

      #(16 only for SOD for other 8)
      array :allowed_factions, :type => 'bit1', initial_length: :length_for_type

      uint8 :is_faction_random
      uint8 :has_main_town

      uint8 :generate_hero_at_main_town,    onlyif: :if_not_roe_version_and_has_main_town?
      uint8 :generate_hero,                 onlyif: :if_not_roe_version_and_has_main_town?

      uint8 :main_town_coord_x,             onlyif: :has_main_town_a?
      uint8 :main_town_coord_y,             onlyif: :has_main_town_a?
      uint8 :main_town_coord_z,             onlyif: :has_main_town_a?

      uint8 :has_random_hero
      uint8 :main_custom_hero_id
      uint8 :main_custom_hero_portrait,     onlyif: :has_custom_hero?

      uint32 :main_custom_hero_name_size,   onlyif: :has_custom_hero?
      string :main_custom_hero_name, read_length: :main_custom_hero_name_size, onlyif: :has_custom_hero?

      struct :heroes_data, onlyif: :if_not_roe_version do
        uint8 :power_placeholders # WTF?
        uint8 :hero_count

        array :offset2, :type => 'uint8', initial_length: 3

        array :heroes, :initial_length => :hero_count do
          uint8 :hero_id

          uint32 :hero_name_size
          string :hero_name, read_length: :hero_name_size
        end
      end
    end

    def length_for_type
      if parent.parent.heroes_version == 0x1C # SOD + WOG
        16
      else
        8
      end
    end

    def has_custom_hero?
      info.main_custom_hero_id != 0xff
    end

    def has_main_town_a?
      info.has_main_town.nonzero?
    end

    def if_not_roe_version_and_has_main_town?
      has_main_town_a? && if_not_roe_version
    end

    def if_sod_version
      parent.parent.heroes_version == 0x1C
    end


    def if_not_roe_version
      parent.parent.heroes_version != 0x0E
    end

  end

  class HeroSettingsRecord < BinData::Record
    endian :little

    uint8 :custom

    struct :info, onlyif: :is_custom do
      uint8 :has_exp

      #TODO more details
    end

    def is_custom
      custom != 0x00
    end

  end

  class TileRecord < BinData::Record
    endian :little

    uint8 :type
    uint8 :view
    uint8 :river_type
    uint8 :river_dir
    uint8 :road_type
    uint8 :road_dir
    uint8 :ext_tile_flag

  end

  class MapRecord < BinData::Record
    endian :little

    uint32  :heroes_version

    uint8   :areAnyPlayers

    uint32  :map_size

    uint8   :map_has_subterranean

    uint32  :map_name_size
    string  :map_name, read_length: :map_name_size

    uint32  :map_desc_size
    string  :map_desc, read_length: :map_desc_size

    uint8   :map_difficulty

    uint8   :max_level, :onlyif => :unless_roe_version

    array   :players, type: :player_record, initial_length: 8

    struct :victory_loss_conditions do
      uint8 :vic_condition
      # │   ■ FF - NO
      # │   ■ 00 - Acquire a specific artifact
      # │   ■ 01 - Accumulate creatures
      # │   ■ 02 - Accumulate resources
      # │   ■ 03 - Upgrade a specific town
      # │   ■ 04 - Build the grail structure
      # │   ■ 05 - Defeat a specific Hero
      # │   ■ 06 - Capture a specific town
      # │   ■ 07 - Defeat a specific monster
      # │   ■ 08 - Flag all creature dwelling
      # │   ■ 09 - Flag all mines
      # │   ■ 0A - Transport a specific artifact

      struct :special_conds, onlyif: :not_default_vic_cond do
        uint8 :allow_normal_victory
        uint8 :applies_to_ai

        # ############################################################
        # Acquire a specific artifact
        struct :art_conds, onlyif: :victory_with_art do
          uint8 :object_type

          #TODO fix for normal offset
          array :offset1, :type => 'uint8', initial_length: 1, onlyif: :unless_roe_version
        end

        # ############################################################
        # Accumulate creatures
        struct :accum_creatures_conds, onlyif: :victory_with_accum_creatures do
          uint8 :object_type

          #TODO fix for normal offset
          array :offset1, :type => 'uint8', initial_length: 1, onlyif: :unless_roe_version

          uint32 :target_count
        end

        # ############################################################
        # Accumulate resources
        struct :accum_resources_conds, onlyif: :victory_with_accum_resources do
          uint8 :object_type

          uint32 :target_count
        end

      end

      uint8 :loss_condition
      # │   ■ FF - None
      # │   ■ 00 - Lose a specific town
      # │   ■ 01 - Lose a specific hero
      # │   ■ 02 - Time expires

      struct :special_loss_conds, onlyif: :not_default_loss_cond do

        # ############################################################
        # Lose a specific town
        struct :loss_town_conds, onlyif: :loss_with_lose_town do
          uint8 :coord_x
          uint8 :coord_y
          uint8 :coord_z
        end

        # ############################################################
        # Lose a specific hero
        struct :loss_hero_conds, onlyif: :loss_with_lose_hero do
          uint8 :coord_x
          uint8 :coord_y
          uint8 :coord_z
        end

        # ############################################################
        # Time expires
        struct :time_expired_conds, onlyif: :loss_with_time_expired do
          uint16 :days_limit
        end

      end
    end

    uint8 :teams_count

    struct :heroes_data, onlyif: :has_teams? do
      uint8 :player1_team
      uint8 :player2_team
      uint8 :player3_team
      uint8 :player4_team
      uint8 :player5_team
      uint8 :player6_team
      uint8 :player7_team
      uint8 :player8_team
    end

    array :allowed_heroes, :type => 'bit1', initial_length: :heroes_mask_size

    def heroes_mask_size
      (unless_roe_version ? 20 : 16) * 8
    end

    # WTF?
    uint32  :placeholders_qty, onlyif: :unless_roe_version
    array   :placeholded_heroes, :type => 'uint8', initial_length: :placeholders_qty, onlyif: :unless_roe_version

    uint8  :disposed_qty, onlyif: :upper_sod_version

    array :disposed_heroes, initial_length: :disposed_qty, onlyif: :upper_sod_version do
      uint8   :hero_id
      uint8   :portait

      uint32  :hero_name_size
      string  :hero_name, read_length: :hero_name_size

      uint8   :players
    end

    array :null_offset1, :type => 'uint8', initial_length: 31

    array :allowed_arts, :type => 'bit1', initial_length: :arts_mask_size, onlyif: :unless_roe_version

    array :allowed_spells,     :type => 'bit1', initial_length: 9 * 8, onlyif: :upper_sod_version
    array :allowed_abilities,  :type => 'bit1', initial_length: 4 * 8, onlyif: :upper_sod_version

    def arts_mask_size
      (heroes_version == 0x15 ? 17 : 18) * 8 # == AB
    end

    uint32 :rumors_qty # Слухи
    #TODO blah blah

    array :predefined_heroes, type: :hero_settings_record, initial_length: 156, onlyif: :upper_sod_version_and
    def upper_sod_version_and
      upper_sod_version# && false
    end

    array :ground,      type: :tile_record, initial_length: :tiles_count
    array :underground, type: :tile_record, initial_length: :tiles_count, onlyif: :has_subterranean?

    def tiles_count
      map_size * map_size
    end

    def has_subterranean?
      map_has_subterranean == 1
    end
    # ############################################################
    # rules by version
    # ############################################################
    def unless_roe_version
      heroes_version != 0x0E # !ROE
    end

    def upper_sod_version
      heroes_version >= 0x1C # >= SOD
    end

    # ############################################################
    # rules by victory condition
    # ############################################################
    def not_default_vic_cond
      victory_loss_conditions.vic_condition != 0xFF
    end

    def not_default_loss_cond
      victory_loss_conditions.loss_condition != 0xFF
    end

    def victory_with_art
      victory_loss_conditions.vic_condition == 0x00
    end

    def victory_with_accum_creatures
      victory_loss_conditions.vic_condition == 0x01
    end

    def victory_with_accum_resources
      victory_loss_conditions.vic_condition == 0x02
    end

    # ############################################################
    # rules by loss condition
    # ############################################################
    def loss_with_lose_town
      victory_loss_conditions.loss_condition == 0x00
    end

    def loss_with_lose_hero
      victory_loss_conditions.loss_condition == 0x01
    end

    def loss_with_time_expired
      victory_loss_conditions.loss_condition == 0x02
    end

    # ############################################################
    # rules by teams
    # ############################################################
    def has_teams?
      teams_count > 0
    end

  end

end