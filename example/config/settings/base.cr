Marten.configure do |config|
  config.secret_key = "__insecure_example_only__"
  config.debug = true
  config.host = "127.0.0.1"
  config.port = 8000

  config.installed_apps = [
    MartenLucide::App,
  ]

  config.lucide.version = "1.37.0"
  config.lucide.sha256 = "d001ff465039224ad2936b5da7876d0549949bf81e648eb3cee50505f35822d8"
end
