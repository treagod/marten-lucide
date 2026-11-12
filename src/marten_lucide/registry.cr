module MartenLucide
  # Loaded once per process; renders never touch the disk.
  module Registry
    extend self

    @@icons : Hash(String, String)? = nil
    @@mutex = Mutex.new

    def fetch?(name : String) : String?
      icons[name]?
    end

    def names : Array(String)
      icons.keys.sort!
    end

    def clear : Nil
      @@mutex.synchronize { @@icons = nil }
    end

    # For test suites: plain `.svg` files instead of a synced cache.
    def use_svg_directory(path : String) : Nil
      icons = Dir.glob(File.join(path, "*.svg")).to_h do |file|
        name = File.basename(file, ".svg")
        {name, Sanitizer.from_svg(name, File.read(file))}
      end

      @@mutex.synchronize { @@icons = icons }
    end

    private def icons : Hash(String, String)
      @@icons || @@mutex.synchronize { @@icons ||= load }
    end

    private def load : Hash(String, String)
      settings = Marten.settings.lucide
      version = settings.version!
      entry = Cache.read(version)

      if entry.nil? || entry.version != version || entry.sha256 != settings.sha256
        raise Errors::NotSynced.new(version, Cache.path(version))
      end

      # Sanitized again so a hand-edited cache file cannot put markup on a page.
      icons = entry.icons.to_h { |name, body| {name, Sanitizer.body(name, body)} }
      entry.aliases.each { |alias_name, target| icons[alias_name] ||= icons[target] if icons.has_key?(target) }
      icons
    end
  end
end
