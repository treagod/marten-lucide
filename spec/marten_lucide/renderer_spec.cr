require "../spec_helper"

describe MartenLucide::Renderer do
  it "renders without a template" do
    sync_fixture

    out = MartenLucide::Renderer.render("search", size: 20, stroke_width: 1.5, css_class: "foo",
      attributes: {"data-turbo" => "false"})

    out.should contain %(width="20" height="20")
    out.should contain %(stroke-width="1.5")
    out.should contain %(class="lucide lucide-search foo")
    out.should contain %(data-turbo="false")
  end

  {"onclick", "style", "aria-hidden", "aria-label", "data-x\"y", "data-"}.each do |name|
    it "rejects the attribute #{name.inspect}" do
      sync_fixture

      expect_raises(ArgumentError, "Unsupported Lucide icon attribute") do
        MartenLucide::Renderer.render("search", attributes: {name => "x"})
      end
    end
  end
end
