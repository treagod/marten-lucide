ENV["MARTEN_ENV"] = "test"

require "spec"
require "log/spec"
require "file_utils"
require "http/server"

require "marten"
require "../src/marten_lucide"
require "../src/marten_lucide/cli"
require "./support/**"

Marten.configure :test do |config|
  config.installed_apps = [MartenLucide::App]
  config.secret_key = "__insecure_#{Random::Secure.random_bytes(32).hexstring}__"
  config.log_level = ::Log::Severity::None
end

Spec.before_suite { Marten.setup }

Spec.around_each do |example|
  settings = Marten.settings.lucide
  cache_dir = File.join(Dir.tempdir, "marten-lucide-spec-#{Random::Secure.hex(8)}")

  settings.version = "9.9.9"
  settings.sha256 = nil
  settings.cache_dir = cache_dir
  settings.release_url = MartenLucide::Settings::DEFAULT_RELEASE_URL
  settings.raise_on_unknown_icon = nil
  MartenLucide::Registry.clear

  begin
    example.run
  ensure
    FileUtils.rm_rf(cache_dir)
  end
end
