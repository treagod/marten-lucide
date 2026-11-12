require "../marten_lucide"
require "marten/cli"

module MartenLucide
  module CLI
    # `marten lucide sync [--force] [--archive=PATH]`
    class Lucide < Marten::CLI::Manage::Command::Base
      command_name :lucide
      help "Download, verify and cache the Lucide release pinned in config.lucide."

      @subcommand : String? = nil
      @force = false
      @archive : String? = nil

      def setup
        on_argument(:subcommand, "Subcommand to run (sync)") { |value| @subcommand = value }
        on_option(:force, "Re-download even if the version is already cached") { @force = true }
        on_option_with_arg(:archive, :path, "Use a local lucide-icons-<version>.zip instead of downloading") do |value|
          @archive = value
        end
      end

      def run
        case @subcommand
        when "sync" then sync
        when nil    then print_error_and_exit("A subcommand is required: sync")
        else             print_error_and_exit("Unknown subcommand '#{@subcommand}', expected: sync")
        end
      end

      private def sync
        version = Marten.settings.lucide.version!
        archive = @archive.try { |path| File.open(path, &.getb_to_end) }

        print("Syncing Lucide #{style(version, mode: :bold)}...")
        result = Sync.call(archive: archive, force: @force)

        if result.skipped
          print("Already cached: #{result.icon_count} icons in #{Cache.path(version)} (--force re-downloads)")
        else
          print("#{style("Done", fore: :light_green)}: #{result.icon_count} icons, sha256 #{result.sha256}, " \
                "written to #{Cache.path(version)}")
        end
      rescue ex : Errors::Base | File::Error
        print_error_and_exit(ex.message.to_s)
      end
    end
  end
end
