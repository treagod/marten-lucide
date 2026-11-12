require "../spec_helper"

private def run_command(options : Array(String)) : {Int32, String, String}
  stdout = IO::Memory.new
  stderr = IO::Memory.new
  command = MartenLucide::CLI::Lucide.new(options: options, stdout: stdout, stderr: stderr, exit_raises: true)

  {command.handle, stdout.to_s, stderr.to_s}
end

describe MartenLucide::CLI::Lucide do
  it "syncs from a local archive" do
    archive = build_archive
    Marten.settings.lucide.sha256 = sha256_of(archive)
    path = File.join(Dir.tempdir, "lucide-icons-#{Random::Secure.hex(4)}.zip")
    File.write(path, archive)

    begin
      code, stdout, _ = run_command(["sync", "--archive=#{path}"])

      code.should eq 0
      stdout.should contain "3 icons"
      File.exists?(MartenLucide::Cache.path("9.9.9")).should be_true

      code, stdout, _ = run_command(["sync", "--archive=#{path}"])
      code.should eq 0
      stdout.should contain "Already cached"
    ensure
      File.delete?(path)
    end
  end

  it "reports a verification failure" do
    path = File.join(Dir.tempdir, "lucide-icons-#{Random::Secure.hex(4)}.zip")
    File.write(path, build_archive)

    begin
      code, _, stderr = run_command(["sync", "--archive=#{path}"])

      code.should eq 1
      stderr.should contain "No sha256 configured"
    ensure
      File.delete?(path)
    end
  end

  it "reports a missing archive file" do
    code, _, stderr = run_command(["sync", "--archive=/nonexistent/lucide.zip"])

    code.should eq 1
    stderr.should contain "/nonexistent/lucide.zip"
  end

  it "requires a known subcommand" do
    run_command([] of String)[0].should eq 1
    run_command(["update"])[2].should contain "Unknown subcommand 'update'"
  end
end
