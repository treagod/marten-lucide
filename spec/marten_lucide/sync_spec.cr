require "../spec_helper"

describe MartenLucide::Sync do
  it "verifies, sanitizes and caches the archive" do
    result = sync_fixture

    result.skipped.should be_false
    result.icon_count.should eq 3

    entry = MartenLucide::Cache.read("9.9.9").not_nil!
    entry.sha256.should eq result.sha256
    entry.icons["search"].should eq %(<path d="m21 21-4.34-4.34"/><circle cx="11" cy="11" r="8"/>)
    entry.aliases.should eq({"home" => "house"})
  end

  it "skips a version that is already cached with the pinned checksum" do
    sync_fixture

    # Would fail verification if it were used.
    result = MartenLucide::Sync.call(archive: Bytes.new(1))

    result.skipped.should be_true
    result.icon_count.should eq 3
  end

  it "re-syncs when forced" do
    sync_fixture
    archive = build_archive({"search" => %(<path d="M1 1"/>)})
    Marten.settings.lucide.sha256 = sha256_of(archive)

    MartenLucide::Sync.call(archive: archive, force: true).icon_count.should eq 1
  end

  it "keeps versions side by side" do
    sync_fixture
    Marten.settings.lucide.version = "1.2.3"
    sync_fixture

    File.exists?(MartenLucide::Cache.path("9.9.9")).should be_true
    File.exists?(MartenLucide::Cache.path("1.2.3")).should be_true
  end

  it "accepts GitHub's sha256:<hex> digest format" do
    archive = build_archive
    Marten.settings.lucide.sha256 = "sha256:#{sha256_of(archive).upcase}"

    MartenLucide::Sync.call(archive: archive).skipped.should be_false
  end

  it "ignores files outside icons/ and non-icon names" do
    archive = build_archive(extra: {
      "README.md"         => "hi",
      "icons/../evil.svg" => svg_file("<script/>"),
      "other/x.svg"       => "x",
    })
    Marten.settings.lucide.sha256 = sha256_of(archive)

    MartenLucide::Sync.call(archive: archive).icon_count.should eq 3
  end

  describe "verification" do
    it "refuses to write anything without a pinned checksum and reports the digest" do
      archive = build_archive

      error = expect_raises(MartenLucide::Errors::VerificationFailed) { MartenLucide::Sync.call(archive: archive) }

      error.message.not_nil!.should contain %(config.lucide.sha256 = "#{sha256_of(archive)}")
      error.message.not_nil!.should contain "releases/tag/9.9.9"
      File.exists?(MartenLucide::Cache.path("9.9.9")).should be_false
    end

    it "refuses an archive whose checksum does not match" do
      Marten.settings.lucide.sha256 = "0" * 64

      expect_raises(MartenLucide::Errors::VerificationFailed, "failed verification") do
        MartenLucide::Sync.call(archive: build_archive)
      end

      File.exists?(MartenLucide::Cache.path("9.9.9")).should be_false
    end

    it "verifies before unzipping" do
      Marten.settings.lucide.sha256 = "0" * 64

      expect_raises(MartenLucide::Errors::VerificationFailed) { MartenLucide::Sync.call(archive: "not a zip".to_slice) }
    end

    it "keeps the previous cache when a forced re-sync fails" do
      sync_fixture
      tampered = build_archive({"search" => %(<path d="M0 0"/>)})

      expect_raises(MartenLucide::Errors::VerificationFailed) do
        MartenLucide::Sync.call(archive: tampered, force: true)
      end

      MartenLucide::Registry.fetch?("search").not_nil!.should contain "circle"
    end

    {"latest", "^1.0", "1.x", "1.37", "v1.37.0"}.each do |version|
      it "rejects the non-exact version #{version.inspect}" do
        Marten.settings.lucide.version = version

        expect_raises(MartenLucide::Errors::NotConfigured, "exact release") do
          MartenLucide::Sync.call(archive: build_archive)
        end
      end
    end

    it "requires a version" do
      Marten.settings.lucide.version = nil

      expect_raises(MartenLucide::Errors::NotConfigured, "No Lucide version configured") { MartenLucide::Sync.call }
    end
  end

  describe "archive limits" do
    it "rejects an archive without icons" do
      archive = build_archive({} of String => String, extra: {} of String => String)
      Marten.settings.lucide.sha256 = sha256_of(archive)

      expect_raises(MartenLucide::Errors::InvalidArchive, "contained no icons") do
        MartenLucide::Sync.call(archive: archive)
      end
    end

    it "rejects an oversized entry" do
      archive = build_archive({"huge" => %(<path d="#{"1" * 70_000}"/>)})
      Marten.settings.lucide.sha256 = sha256_of(archive)

      expect_raises(MartenLucide::Errors::InvalidArchive, "larger than 64 KB") do
        MartenLucide::Sync.call(archive: archive)
      end
    end

    it "rejects a pinned archive that is not a zip" do
      archive = "not a zip".to_slice
      Marten.settings.lucide.sha256 = sha256_of(archive)

      expect_raises(MartenLucide::Errors::InvalidArchive) { MartenLucide::Sync.call(archive: archive) }
    end

    it "rejects the whole release when one icon fails sanitizing" do
      archive = build_archive(SAMPLE_ICONS.merge({"evil" => %(<script>alert(1)</script>)}))
      Marten.settings.lucide.sha256 = sha256_of(archive)

      expect_raises(MartenLucide::Errors::InvalidIcon, %("evil")) { MartenLucide::Sync.call(archive: archive) }
      File.exists?(MartenLucide::Cache.path("9.9.9")).should be_false
    end
  end
end

describe MartenLucide::Cache do
  it "prefers the setting, then MARTEN_LUCIDE_CACHE_DIR" do
    MartenLucide::Cache.dir.should eq Marten.settings.lucide.cache_dir

    Marten.settings.lucide.cache_dir = nil
    previous = ENV["MARTEN_LUCIDE_CACHE_DIR"]?

    begin
      ENV["MARTEN_LUCIDE_CACHE_DIR"] = "/tmp/lucide-env"
      MartenLucide::Cache.dir.should eq "/tmp/lucide-env"
      MartenLucide::Cache.path("1.2.3").should eq "/tmp/lucide-env/1.2.3.json"

      ENV.delete("MARTEN_LUCIDE_CACHE_DIR")
      MartenLucide::Cache.dir.should end_with "marten-lucide"
    ensure
      ENV["MARTEN_LUCIDE_CACHE_DIR"] = previous
    end
  end
end
