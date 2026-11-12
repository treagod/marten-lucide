module MartenLucide
  # `{% lucide "name" size: 20 class: "icon" aria_label: "Search" data_action: "click->x#y" %}`
  class TemplateTag < Marten::Template::Tag::Base
    include Marten::Template::Tag::CanSplitSmartly

    OPTIONS = %w[size stroke_width class color aria_label]

    private PASSTHROUGH_RE = /\A(?:data|aria)_[a-z0-9]+(?:_[a-z0-9]+)*\z/

    @name : Marten::Template::FilterExpression
    @options = {} of String => Marten::Template::FilterExpression

    def initialize(_parser : Marten::Template::Parser, source : String)
      parts = split_smartly(source)
      raise syntax_error(%(an icon name is required, e.g. {% lucide "search" %})) if parts.size < 2

      @name = Marten::Template::FilterExpression.new(parts[1].rchop(','))

      each_option(parts[2..]) do |key, value|
        unless OPTIONS.includes?(key) || passthrough?(key)
          raise syntax_error("unsupported argument '#{key}' (supported: #{OPTIONS.join(", ")}, data_*, aria_*)")
        end

        raise syntax_error("'#{key}' given more than once") if @options.has_key?(key)

        @options[key] = Marten::Template::FilterExpression.new(value)
      end
    end

    def render(context : Marten::Template::Context) : String
      attributes = nil

      @options.each_key do |key|
        next if OPTIONS.includes?(key)
        next unless value = option(context, key)

        (attributes ||= {} of String => String)[key.tr("_", "-")] = value
      end

      Renderer.render(
        @name.resolve(context).to_s,
        size: option(context, "size"),
        stroke_width: option(context, "stroke_width"),
        css_class: option(context, "class"),
        color: option(context, "color"),
        aria_label: option(context, "aria_label"),
        attributes: attributes,
      )
    end

    private def passthrough?(key : String) : Bool
      key.matches?(PASSTHROUGH_RE) && !Renderer::RESERVED_ATTRIBUTES.includes?(key.tr("_", "-"))
    end

    private def option(context : Marten::Template::Context, key : String) : String?
      @options[key]?.try { |expression| expression.resolve(context).raw.try(&.to_s).presence }
    end

    # Marten's `CanExtractKwargs` reads `size: 20 class: "x"` as one value for `size`, so the tokens from
    # `split_smartly` are paired here. Both space- and comma-separated options work.
    private def each_option(tokens : Array(String), &)
      tokens = tokens.map(&.rchop(',')).reject(&.empty?)
      index = 0

      while index < tokens.size
        match = tokens[index].match(/\A(\w+):(.*)\z/)
        raise syntax_error("expected 'name: value', got '#{tokens[index]}'") unless match

        if match[2].empty?
          index += 1
          raise syntax_error("'#{match[1]}:' is missing a value") if index >= tokens.size
          yield match[1], tokens[index]
        else
          yield match[1], match[2]
        end

        index += 1
      end
    end

    private def syntax_error(message : String) : Marten::Template::Errors::InvalidSyntax
      Marten::Template::Errors::InvalidSyntax.new("Malformed lucide tag: #{message}")
    end
  end
end

Marten::Template::Tag.register("lucide", MartenLucide::TemplateTag)
