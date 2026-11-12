require "../spec_helper"

private def with_release_server(archive : Bytes, &)
  server = HTTP::Server.new do |context|
    case context.request.path
    when "/download/9.9.9/lucide-icons-9.9.9.zip"
      context.response.status = :found
      context.response.headers["Location"] = "/assets/lucide-icons-9.9.9.zip"
    when "/assets/lucide-icons-9.9.9.zip"
      context.response.content_type = "application/zip"
      context.response.write(archive)
    when "/loop"
      context.response.status = :found
      context.response.headers["Location"] = "/loop"
    else
      context.response.status = :not_found
    end
  end

  address = server.bind_tcp("127.0.0.1", 0)
  spawn { server.listen }

  begin
    yield "http://127.0.0.1:#{address.port}"
  ensure
    server.close
  end
end

describe MartenLucide::Download do
  it "syncs from a release URL, following its redirect" do
    archive = build_archive

    with_release_server(archive) do |base|
      Marten.settings.lucide.release_url = "#{base}/download/%{version}/lucide-icons-%{version}.zip"
      Marten.settings.lucide.sha256 = sha256_of(archive)

      result = MartenLucide::Sync.call

      result.skipped.should be_false
      result.icon_count.should eq 3
    end
  end

  it "fails on an HTTP error" do
    with_release_server(build_archive) do |base|
      expect_raises(MartenLucide::Errors::DownloadFailed, "HTTP 404") do
        MartenLucide::Download.fetch("#{base}/missing.zip")
      end
    end
  end

  it "stops after too many redirects" do
    with_release_server(build_archive) do |base|
      expect_raises(MartenLucide::Errors::DownloadFailed, "Too many redirects") do
        MartenLucide::Download.fetch("#{base}/loop")
      end
    end
  end

  it "reports an unreachable host" do
    expect_raises(MartenLucide::Errors::DownloadFailed, "Could not download") do
      MartenLucide::Download.fetch("http://127.0.0.1:1/lucide.zip")
    end
  end

  it "never follows a redirect from HTTPS to HTTP" do
    expect_raises(MartenLucide::Errors::DownloadFailed, "non-HTTPS") do
      MartenLucide::Download.redirect_target(URI.parse("https://github.com/a.zip"), "http://mirror.test/a.zip")
    end

    MartenLucide::Download.redirect_target(URI.parse("https://github.com/a/b.zip"), "/c.zip")
      .to_s.should eq "https://github.com/c.zip"
  end
end
