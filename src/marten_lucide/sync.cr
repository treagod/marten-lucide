require "compress/zip"
require "digest/sha256"

module MartenLucide
  # The archive is verified before it is unzipped.
  module Sync
    extend self

    record Result, version : String, sha256 : String, icon_count : Int32, skipped : Bool

    MAX_ENTRIES     = 10_000
    MAX_ENTRY_BYTES = 64 * 1024

    private ENTRY_RE = %r{\Aicons/([a-z0-9]+(?:-[a-z0-9]+)*)\.(svg|json)\z}
    private NAME_RE  = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

    def call(archive : Bytes? = nil, force : Bool = false) : Result
      settings = Marten.settings.lucide
      version = settings.version!
      expected = settings.sha256

      if !force && (cached = Cache.read(version)) && cached.sha256 == expected
        return Result.new(version, cached.sha256, cached.icons.size, true)
      end

      archive ||= Download.fetch(settings.release_url % {version: version})
      actual = Digest::SHA256.hexdigest(archive)
      verify!(version, expected, actual)

      icons, aliases = extract(version, archive)
      Cache.write(Cache::Entry.new(version, actual, icons, aliases))
      Registry.clear

      Result.new(version, actual, icons.size, false)
    end

    private def verify!(version : String, expected : String?, actual : String) : Nil
      if expected.nil?
        raise Errors::VerificationFailed.new(
          "No sha256 configured for Lucide #{version}; nothing was written.\n\n" \
          "The downloaded archive has sha256 #{actual}.\n" \
          "Compare it with the digest of lucide-icons-#{version}.zip on " \
          "https://github.com/lucide-icons/lucide/releases/tag/#{version}, then pin it:\n\n" \
          "    config.lucide.sha256 = \"#{actual}\"\n"
        )
      end

      return if expected == actual

      raise Errors::VerificationFailed.new(
        "Lucide #{version} archive failed verification; nothing was written.\n\n" \
        "Expected sha256 #{expected}\nGot      sha256 #{actual}\n\n" \
        "If you changed config.lucide.version, update config.lucide.sha256 as well."
      )
    end

    private def extract(version : String, archive : Bytes) : {Hash(String, String), Hash(String, String)}
      icons = {} of String => String
      aliases = {} of String => String
      entries = 0

      Compress::Zip::Reader.open(IO::Memory.new(archive)) do |zip|
        zip.each_entry do |entry|
          entries += 1
          raise Errors::InvalidArchive.new("Archive has more than #{MAX_ENTRIES} entries") if entries > MAX_ENTRIES

          next unless match = entry.filename.match(ENTRY_RE)

          name, kind = match[1], match[2]
          content = read_entry(entry)

          if kind == "svg"
            icons[name] = Sanitizer.from_svg(name, content)
          else
            alias_names(content).each { |alias_name| aliases[alias_name] = name }
          end
        end
      end

      raise Errors::InvalidArchive.new("Lucide #{version} archive contained no icons") if icons.empty?

      {icons, aliases.reject { |alias_name, target| icons.has_key?(alias_name) || !icons.has_key?(target) }}
    rescue ex : Compress::Zip::Error
      raise Errors::InvalidArchive.new("Lucide #{version} archive is not a valid zip: #{ex.message}")
    end

    private def read_entry(entry : Compress::Zip::Reader::Entry) : String
      buffer = IO::Memory.new

      if IO.copy(entry.io, buffer, MAX_ENTRY_BYTES + 1) > MAX_ENTRY_BYTES
        raise Errors::InvalidArchive.new("#{entry.filename} is larger than #{MAX_ENTRY_BYTES // 1024} KB")
      end

      buffer.to_s
    end

    # Deprecated names ("home" for "house"): plain strings in older releases, `{"name": …}` in newer ones.
    private def alias_names(json : String) : Array(String)
      list = JSON.parse(json)["aliases"]?.try(&.as_a?) || return [] of String

      list.compact_map { |item| (item.as_s? || item["name"]?.try(&.as_s?)).presence }.select(&.matches?(NAME_RE))
    rescue JSON::ParseException
      [] of String
    end
  end
end
