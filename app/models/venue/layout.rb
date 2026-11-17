module Venue
  # The sections the seat map draws (config/venues/paycom_center.yml): which
  # rows each one has, how many seats, and which side of the center aisle it
  # sits on. Checked when loaded, so a typo in the file fails loudly.
  class Layout
    PATH = Rails.root.join("config/venues/paycom_center.yml")
    SHAPES = %w[baseline corner].freeze
    SIDES = %w[left right].freeze
    # Rows that stand in another row's place (120's accessible row).
    STAND_INS = { "SA" => "S" }.freeze

    class Invalid < StandardError; end

    Row = Data.define(:name, :depth, :seats, :offset)
    Section = Data.define(:id, :shape, :side, :source, :rows) do
      def row(name) = rows.find { |r| r.name == name.to_s.upcase }
    end

    attr_reader :name, :sections

    def self.paycom
      @paycom ||= load(PATH)
    end

    def self.load(path)
      new(YAML.safe_load_file(path, aliases: true))
    end

    def initialize(spec)
      @name = spec.fetch("name")
      @sections = spec.fetch("sections").map { |id, s| build_section(id.to_s, s) }.freeze
    end

    def section(id) = sections.find { |s| s.id == id.to_s.upcase }

    def row(section_id, row_name) = section(section_id)&.row(row_name)

    def section_ids = sections.map(&:id)

    # Compact, for the 3D view: rows as [name, depth, seats, offset].
    def to_client
      { name: name, sections: sections.map do |s|
        { id: s.id, shape: s.shape, side: s.side, estimated: s.source == "estimated",
          rows: s.rows.map { |r| [ r.name, r.depth, r.seats, r.offset ] } }
      end }
    end

    private

    def build_section(id, spec)
      shape = spec.fetch("shape")
      side = spec.fetch("side")
      raise Invalid, "section #{id}: shape #{shape.inspect}" unless SHAPES.include?(shape)
      raise Invalid, "section #{id}: side #{side.inspect}" unless SIDES.include?(side)

      rows = spec.fetch("rows").map { |name, value| build_row(id, name.to_s.upcase, value) }
      raise Invalid, "section #{id} has no rows" if rows.empty?

      Section.new(id: id, shape: shape, side: side, source: spec.fetch("source"), rows: rows.sort_by(&:depth).freeze)
    end

    def build_row(section, name, value)
      depth = Market::RowOrder.rank(STAND_INS.fetch(name, name))
      raise Invalid, "section #{section}: unknown row #{name}" unless depth

      seats, offset = value.is_a?(Hash) ? value.values_at("seats", "offset") : [ value, 0 ]
      seats = Integer(seats)
      offset = Integer(offset || 0)
      raise Invalid, "section #{section} row #{name}: #{seats} seats" unless seats.positive?
      raise Invalid, "section #{section} row #{name}: offset #{offset}" if offset.negative?

      Row.new(name: name, depth: depth, seats: seats, offset: offset)
    end
  end
end
