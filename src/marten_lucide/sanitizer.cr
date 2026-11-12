module MartenLucide
  # Allowlist parser: anything but self-closing shapes with plain geometry rejects the icon. Output is rebuilt from
  # the parsed tokens, never passed through.
  module Sanitizer
    extend self

    ELEMENTS   = %w[path circle rect line polyline polygon ellipse]
    ATTRIBUTES = %w[d cx cy r rx ry x y x1 y1 x2 y2 width height points fill]

    private SVG_RE       = /<svg\b[^>]*>(.*)<\/svg\s*>/m
    private TAG_RE       = /\G\s*<([A-Za-z][\w:.-]*)((?:\s+[^\s=\/>"]+\s*=\s*"[^"]*")*)\s*\/>/
    private TAG_NAME_RE  = /\A\s*<([A-Za-z][\w:.-]*)/
    private ATTRIBUTE_RE = /([^\s=\/>"]+)\s*=\s*"([^"]*)"/
    private VALUE_RE     = /\A[A-Za-z0-9 .,\-]*\z/

    # Drops the outer `<svg>`; the renderer writes its own.
    def from_svg(name : String, source : String) : String
      match = source.match(SVG_RE) || raise invalid(name, "no <svg> element")
      body(name, match[1])
    end

    def body(name : String, source : String) : String
      elements = [] of String
      position = 0

      while match = source.match(TAG_RE, position)
        elements << element(name, match[1], match[2])
        position = match.end
      end

      rest = source[position..]
      unless rest.blank?
        if (tag = rest.match(TAG_NAME_RE)) && !ELEMENTS.includes?(tag[1])
          raise invalid(name, "disallowed element <#{tag[1]}>")
        end

        raise invalid(name, "unexpected content #{rest.strip[0, 40].inspect}")
      end

      raise invalid(name, "empty icon") if elements.empty?

      elements.join
    end

    private def element(name : String, tag : String, attribute_source : String) : String
      raise invalid(name, "disallowed element <#{tag}>") unless ELEMENTS.includes?(tag)

      attributes = {} of String => String

      attribute_source.scan(ATTRIBUTE_RE) do |match|
        attribute, value = match[1], match[2]

        raise invalid(name, "disallowed attribute #{attribute}") unless ATTRIBUTES.includes?(attribute)
        raise invalid(name, "duplicate attribute #{attribute}") if attributes.has_key?(attribute)
        raise invalid(name, "disallowed characters in #{attribute}=#{value.inspect}") unless value.matches?(VALUE_RE)

        attributes[attribute] = value
      end

      String.build do |io|
        io << '<' << tag
        attributes.each { |attribute, value| io << ' ' << attribute << %(=") << value << '"' }
        io << "/>"
      end
    end

    private def invalid(name : String, reason : String) : Errors::InvalidIcon
      Errors::InvalidIcon.new("Lucide icon #{name.inspect}: #{reason}")
    end
  end
end
