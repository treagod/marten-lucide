require "html"

module MartenLucide
  module Renderer
    extend self

    DEFAULT_SIZE         = "24"
    DEFAULT_STROKE_WIDTH = "2"

    ATTRIBUTE_NAME_RE   = /\A(?:data|aria)-[a-z0-9]+(?:-[a-z0-9]+)*\z/
    RESERVED_ATTRIBUTES = %w[aria-hidden aria-label]

    # `attributes` takes extra `data-*` / `aria-*` attributes.
    def render(
      name : String,
      size : Int32 | Float64 | String? = nil,
      stroke_width : Int32 | Float64 | String? = nil,
      css_class : String? = nil,
      color : String? = nil,
      aria_label : String? = nil,
      attributes : Hash(String, String)? = nil,
    ) : String
      attributes.try &.each_key { |key| validate_attribute_name!(key) }

      body = Registry.fetch?(name)
      return unknown(name) unless body

      dimension = size.to_s.presence || DEFAULT_SIZE
      label = aria_label.presence

      String.build do |io|
        io << %(<svg xmlns="http://www.w3.org/2000/svg")
        attribute(io, "width", dimension)
        attribute(io, "height", dimension)
        io << %( viewBox="0 0 24 24" fill="none")
        attribute(io, "stroke", color.presence || "currentColor")
        attribute(io, "stroke-width", stroke_width.to_s.presence || DEFAULT_STROKE_WIDTH)
        io << %( stroke-linecap="round" stroke-linejoin="round")
        attribute(io, "class", ["lucide", "lucide-#{name}", css_class.presence].compact.join(' '))
        attributes.try &.each { |key, value| attribute(io, key, value) }

        if label
          io << %( role="img")
          attribute(io, "aria-label", label)
          io << "><title>" << HTML.escape(label) << "</title>"
        else
          io << %( aria-hidden="true">)
        end

        io << body << "</svg>"
      end
    end

    def validate_attribute_name!(name : String) : Nil
      return if name.matches?(ATTRIBUTE_NAME_RE) && !RESERVED_ATTRIBUTES.includes?(name)

      raise ArgumentError.new("Unsupported Lucide icon attribute #{name.inspect}: only data-* and aria-* " \
                              "(except aria-hidden and aria-label) can be passed through")
    end

    private def attribute(io : IO, name : String, value : String) : Nil
      io << ' ' << name << %(=") << HTML.escape(value) << '"'
    end

    private def unknown(name : String) : String
      error = Errors::UnknownIcon.new(name, Registry.names)
      raise error if Marten.settings.lucide.raise_on_unknown_icon?

      Log.error { error.message }
      ""
    end
  end
end
