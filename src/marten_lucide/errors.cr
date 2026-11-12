require "levenshtein"

module MartenLucide
  module Errors
    class Base < Exception; end

    class NotConfigured < Base; end

    class NotSynced < Base
      def initialize(version : String, path : String)
        super(
          "Lucide #{version} is not synced (expected #{path}, matching config.lucide.sha256).\n\n" \
          "Run:\n\n    marten lucide sync\n"
        )
      end
    end

    class UnknownIcon < Base
      def initialize(name : String, known : Enumerable(String))
        message = %(Unknown Lucide icon "#{name}")

        if suggestion = Levenshtein.find(name, known, 3)
          message += %(. Did you mean "#{suggestion}"?)
        end

        super(message)
      end
    end

    class InvalidIcon < Base; end

    class InvalidArchive < Base; end

    class VerificationFailed < Base; end

    class DownloadFailed < Base; end
  end
end
