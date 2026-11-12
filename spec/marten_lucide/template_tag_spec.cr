require "../spec_helper"

private def render(source : String, context = {} of String => String) : String
  sync_fixture
  render_template(source, context)
end

describe MartenLucide::TemplateTag do
  describe "output" do
    it "renders inline svg with Lucide's defaults" do
      render(%({% lucide "search" %})).should eq(
        %(<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" ) +
        %(stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" ) +
        %(class="lucide lucide-search" aria-hidden="true">) +
        %(<path d="m21 21-4.34-4.34"/><circle cx="11" cy="11" r="8"/></svg>)
      )
    end

    it "applies every option" do
      out = render(
        %({% lucide "search" size: "1em" stroke_width: 1.5 class: "icon big" color: "#c00" aria_label: "Search" ) +
        %(data_controller: "search" data_search_target: "icon" aria_describedby: "hint" %})
      )

      out.should contain %( width="1em" height="1em")
      out.should contain %( stroke="#c00")
      out.should contain %( stroke-width="1.5")
      out.should contain %( class="lucide lucide-search icon big")
      out.should contain %( data-controller="search" data-search-target="icon" aria-describedby="hint")
      out.should_not contain "style="
    end

    it "accepts comma-separated options" do
      out = render(%({% lucide "search" size: 20, class: "icon", stroke_width: 1 %}))

      out.should contain %(width="20")
      out.should contain %(class="lucide lucide-search icon")
      out.should contain %(stroke-width="1")
    end

    it "resolves the name and options from the context" do
      out = render(%({% lucide name size: px class: css %}), {"name" => "trash-2", "px" => 16, "css" => "danger"})

      out.should contain %(<path d="M10 11v6"/>)
      out.should contain %(width="16")
      out.should contain %(class="lucide lucide-trash-2 danger")
    end

    it "leaves out options that resolve to nil or an empty string" do
      out = render(%({% lucide "search" class: missing aria_label: "" data_x: missing %}))

      out.should contain %(class="lucide lucide-search")
      out.should contain %(aria-hidden="true")
      out.should_not contain "data-x"
    end

    it "renders deprecated alias names as their current icon" do
      render(%({% lucide "home" %})).should contain %(<path d="M3 10a2)
    end
  end

  describe "accessibility" do
    it "hides decorative icons from assistive technology" do
      out = render(%({% lucide "search" %}))

      out.should contain %(aria-hidden="true")
      out.should_not contain "role="
      out.should_not contain "<title>"
    end

    it "gives a labelled icon an accessible name and a title" do
      out = render(%({% lucide "search" aria_label: "Search" %}))

      out.should contain %( role="img" aria-label="Search"><title>Search</title><path)
      out.should_not contain "aria-hidden"
    end
  end

  describe "escaping" do
    {"class", "aria_label", "color", "size", "data_x"}.each do |option|
      it "escapes #{option}" do
        out = render(%({% lucide "search" #{option}: injected %}), {"injected" => %("><script>alert(1)</script>)})

        out.should_not contain "<script>"
        out.should contain "&quot;&gt;&lt;script&gt;"
      end
    end
  end

  describe "unknown icons" do
    it "raises outside production with a suggestion" do
      error = expect_raises(MartenLucide::Errors::UnknownIcon) { render(%({% lucide "serach" %})) }

      error.message.should eq %(Unknown Lucide icon "serach". Did you mean "search"?)
    end

    it "logs and renders nothing when raising is turned off" do
      Marten.settings.lucide.raise_on_unknown_icon = false

      Log.capture("marten_lucide") do |logs|
        render(%(<b>{% lucide "serach" %}</b>)).should eq "<b></b>"
        logs.check(:error, /Unknown Lucide icon "serach"/)
      end
    end

    it "raises by default outside production" do
      Marten.settings.lucide.raise_on_unknown_icon?.should be_true
    end

    it "treats a path-like name as unknown" do
      expect_raises(MartenLucide::Errors::UnknownIcon) { render(%({% lucide "../9.9.9" %})) }
    end
  end

  describe "syntax" do
    {
      %({% lucide %})                               => "an icon name is required",
      %({% lucide "search" colour: "red" %})        => "unsupported argument 'colour'",
      %({% lucide "search" aria_hidden: "false" %}) => "unsupported argument 'aria_hidden'",
      %({% lucide "search" style: "x" %})           => "unsupported argument 'style'",
      %({% lucide "search" size: 20 size: 30 %})    => "'size' given more than once",
      %({% lucide "search" size %})                 => "expected 'name: value'",
      %({% lucide "search" size: %})                => "'size:' is missing a value",
    }.each do |source, message|
      it "rejects #{source} at compile time" do
        expect_raises(Marten::Template::Errors::InvalidSyntax, message) { Marten::Template::Template.new(source) }
      end
    end
  end
end
