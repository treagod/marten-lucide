require "compress/zip"
require "digest/sha256"

SAMPLE_ICONS = {
  "search"  => %(<path d="m21 21-4.34-4.34" />\n  <circle cx="11" cy="11" r="8" />),
  "trash-2" => %(<path d="M10 11v6" />),
  "house"   => %(<path d="M3 10a2 2 0 0 1 .709-1.528l7-6a2 2 0 0 1 2.582 0l7 6A2 2 0 0 1 21 10v9" />),
}

def svg_file(body : String) : String
  <<-SVG
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      #{body}
    </svg>
    SVG
end

# A zip shaped like Lucide's `lucide-icons-<version>.zip`.
def build_archive(
  icons : Hash(String, String) = SAMPLE_ICONS,
  extra : Hash(String, String) = {"icons/house.json" => %({"aliases": [{"name": "home", "deprecated": true}]})},
) : Bytes
  io = IO::Memory.new

  Compress::Zip::Writer.open(io) do |zip|
    icons.each { |name, body| zip.add("icons/#{name}.svg", svg_file(body)) }
    extra.each { |path, content| zip.add(path, content) }
  end

  io.to_slice
end

def sha256_of(bytes : Bytes) : String
  Digest::SHA256.hexdigest(bytes)
end

def sync_fixture(archive : Bytes = build_archive) : MartenLucide::Sync::Result
  Marten.settings.lucide.sha256 = sha256_of(archive)
  MartenLucide::Sync.call(archive: archive)
end

def render_template(source : String, context = {} of String => String) : String
  Marten::Template::Template.new(source).render(context)
end
