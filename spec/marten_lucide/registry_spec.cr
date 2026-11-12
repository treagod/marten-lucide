require "../spec_helper"

describe MartenLucide::Registry do
  it "serves icons from memory after the first lookup" do
    sync_fixture
    MartenLucide::Registry.fetch?("search").should_not be_nil

    File.delete(MartenLucide::Cache.path("9.9.9"))

    MartenLucide::Registry.fetch?("trash-2").should eq %(<path d="M10 11v6"/>)
    MartenLucide::Renderer.render("search").should contain "<circle"
  end

  it "reloads after clear" do
    sync_fixture
    MartenLucide::Registry.fetch?("search")
    File.delete(MartenLucide::Cache.path("9.9.9"))

    MartenLucide::Registry.clear

    expect_raises(MartenLucide::Errors::NotSynced) { MartenLucide::Registry.fetch?("search") }
  end

  it "picks up a fresh sync without a restart" do
    sync_fixture
    MartenLucide::Registry.fetch?("trash-2").should_not be_nil

    archive = build_archive({"search" => %(<path d="M1 1"/>)})
    Marten.settings.lucide.sha256 = sha256_of(archive)
    MartenLucide::Sync.call(archive: archive, force: true)

    MartenLucide::Registry.fetch?("trash-2").should be_nil
  end

  it "tells the developer to sync when nothing is cached" do
    error = expect_raises(MartenLucide::Errors::NotSynced) { render_template(%({% lucide "search" %})) }

    error.message.not_nil!.should contain "Lucide 9.9.9 is not synced"
    error.message.not_nil!.should contain "marten lucide sync"
  end

  it "treats a cache for another checksum as not synced" do
    sync_fixture
    MartenLucide::Registry.clear
    Marten.settings.lucide.sha256 = "f" * 64

    expect_raises(MartenLucide::Errors::NotSynced) { MartenLucide::Registry.fetch?("search") }
  end

  it "raises when no version is configured" do
    Marten.settings.lucide.version = nil

    expect_raises(MartenLucide::Errors::NotConfigured) { MartenLucide::Registry.fetch?("search") }
  end

  it "sanitizes the cache file again when loading it" do
    sync_fixture
    path = MartenLucide::Cache.path("9.9.9")
    File.write(path, File.read(path).sub(%(<path d=\\"M10 11v6\\"/>), %(<script>alert(1)</script>)))
    MartenLucide::Registry.clear

    expect_raises(MartenLucide::Errors::InvalidIcon, "disallowed element <script>") do
      MartenLucide::Registry.fetch?("search")
    end
  end

  describe ".use_svg_directory" do
    it "loads plain svg files without a sync" do
      dir = File.join(Marten.settings.lucide.cache_dir.not_nil!, "fixtures")
      Dir.mkdir_p(dir)
      File.write(File.join(dir, "check.svg"), svg_file(%(<path d="M20 6 9 17l-5-5"/>)))

      MartenLucide::Registry.use_svg_directory(dir)

      MartenLucide::Renderer.render("check").should contain %(<path d="M20 6 9 17l-5-5"/>)
      MartenLucide::Registry.names.should eq ["check"]
    end
  end
end
