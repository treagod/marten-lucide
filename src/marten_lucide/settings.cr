module MartenLucide
  class Settings < Marten::Conf::Settings
    namespace :lucide

    DEFAULT_RELEASE_URL =
      "https://github.com/lucide-icons/lucide/releases/download/%{version}/lucide-icons-%{version}.zip"

    # Exact releases only, so renders are reproducible.
    VERSION_RE = /\A\d+\.\d+\.\d+\z/

    property version : String? = nil

    # Bare hex or GitHub's "sha256:<hex>".
    setter sha256 : String? = nil

    property cache_dir : String? = nil
    property release_url : String = DEFAULT_RELEASE_URL

    # `nil` raises everywhere except in production.
    property raise_on_unknown_icon : Bool? = nil

    def version! : String
      version = @version

      if version.nil?
        raise Errors::NotConfigured.new(%(No Lucide version configured. Set one in config/settings/base.cr:\n\n) +
                                        %(    config.lucide.version = "1.37.0"\n))
      end

      unless version.matches?(VERSION_RE)
        raise Errors::NotConfigured.new(
          %(config.lucide.version must be an exact release like "1.37.0", got "#{version}")
        )
      end

      version
    end

    def sha256 : String?
      @sha256.try(&.strip.downcase.lchop("sha256:"))
    end

    def raise_on_unknown_icon? : Bool
      setting = raise_on_unknown_icon
      setting.nil? ? !Marten.env.production? : setting
    end
  end
end
