require "json"

module MartenLucide
  # Written via temp file + rename, so an existing file is a complete sync.
  module Cache
    extend self

    record Entry,
      version : String,
      sha256 : String,
      icons : Hash(String, String),
      aliases : Hash(String, String) do
      include JSON::Serializable
    end

    def dir : String
      Marten.settings.lucide.cache_dir || ENV["MARTEN_LUCIDE_CACHE_DIR"]? || File.join(user_cache_dir, "marten-lucide")
    end

    def path(version : String) : String
      File.join(dir, "#{version}.json")
    end

    def read(version : String) : Entry?
      path = path(version)
      File.open(path) { |file| Entry.from_json(file) } if File.exists?(path)
    end

    def write(entry : Entry) : Nil
      Dir.mkdir_p(dir)
      target = path(entry.version)
      temp = "#{target}.tmp-#{Random::Secure.hex(6)}"

      begin
        File.write(temp, entry.to_json)
        File.rename(temp, target)
      ensure
        File.delete?(temp)
      end
    end

    private def user_cache_dir : String
      if xdg = ENV["XDG_CACHE_HOME"]?.presence
        xdg
      elsif {{ flag?(:darwin) }}
        File.join(Path.home.to_s, "Library", "Caches")
      else
        File.join(Path.home.to_s, ".cache")
      end
    end
  end
end
