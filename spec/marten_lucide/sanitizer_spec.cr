require "../spec_helper"

private def sanitize(body : String) : String
  MartenLucide::Sanitizer.from_svg("test", svg_file(body))
end

private def rejects(body : String, message : String)
  expect_raises(MartenLucide::Errors::InvalidIcon, message) { sanitize(body) }
end

describe MartenLucide::Sanitizer do
  it "rebuilds the body from parsed shapes and drops the outer svg" do
    sanitize(%(<path d="m21 21-4.34-4.34" />\n  <circle  cx="11" cy="11"   r="8"/>))
      .should eq %(<path d="m21 21-4.34-4.34"/><circle cx="11" cy="11" r="8"/>)
  end

  it "accepts every shape Lucide uses" do
    sanitize(<<-SVG).count('<').should eq 7
      <path d="M1 1"/><circle cx="1" cy="1" r="1"/><rect x="1" y="1" width="2" height="2" rx="1" ry="1"/>
      <line x1="1" y1="1" x2="2" y2="2"/><polyline points="1 1 2 2"/><polygon points="1,1 2,2 3,1"/>
      <ellipse cx="1" cy="1" rx="1" ry="2" fill="currentColor"/>
      SVG
  end

  it("rejects script elements") { rejects %(<script>alert(1)</script>), "disallowed element <script>" }
  it("rejects self-closing script elements") { rejects %(<script href="x"/>), "disallowed element <script>" }
  it("rejects foreignObject") { rejects %(<foreignObject width="1"/>), "disallowed element <foreignObject>" }
  it("rejects groups") { rejects %(<g><path d="M1 1"/></g>), "disallowed element <g>" }
  it("rejects use") { rejects %(<use href="#a"/>), "disallowed element <use>" }
  it("rejects event handlers") { rejects %(<path d="M1 1" onload="alert(1)"/>), "disallowed attribute onload" }
  it("rejects href") { rejects %(<path href="https://evil.test"/>), "disallowed attribute href" }
  it("rejects xlink:href") { rejects %(<path xlink:href="#a"/>), "disallowed attribute xlink:href" }
  it("rejects style") { rejects %(<path style="fill:red"/>), "disallowed attribute style" }
  it("rejects javascript: values") { rejects %(<path d="javascript:alert(1)"/>), "disallowed characters" }
  it("rejects url() values") { rejects %(<path fill="url(#a)"/>), "disallowed characters" }
  it("rejects entities in values") { rejects %(<path d="&#106;"/>), "disallowed characters" }
  it("rejects duplicate attributes") { rejects %(<path d="M1 1" d="M2 2"/>), "duplicate attribute d" }
  it("rejects comments") { rejects %(<!-- <path d="M1 1"/> -->), "unexpected content" }
  it("rejects CDATA") { rejects %(<![CDATA[<script>x</script>]]>), "unexpected content" }
  it("rejects text") { rejects %(<path d="M1 1"/>hello), "unexpected content" }
  it("rejects entities") { rejects %(&lt;script&gt;), "unexpected content" }
  it("rejects open tags") { rejects %(<path d="M1 1">), "unexpected content" }
  it("rejects single-quoted attributes") { rejects %(<path d='M1 1'/>), "unexpected content" }
  it("rejects an empty icon") { rejects "", "empty icon" }

  it "rejects a file without svg element" do
    expect_raises(MartenLucide::Errors::InvalidIcon, "no <svg> element") do
      MartenLucide::Sanitizer.from_svg("test", %(<path d="M1 1"/>))
    end
  end
end
