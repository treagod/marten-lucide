require "http/client"

module MartenLucide
  module Download
    extend self

    MAX_BYTES     = 50 * 1024 * 1024
    MAX_REDIRECTS = 5

    def fetch(url : String) : Bytes
      uri = URI.parse(url)

      (MAX_REDIRECTS + 1).times do
        location = nil

        body = get(uri) do |response|
          if response.status.redirection? && (header = response.headers["Location"]?)
            location = header
            next
          end

          unless response.success?
            raise Errors::DownloadFailed.new("Could not download #{uri} (HTTP #{response.status_code})")
          end

          read_limited(response.body_io, uri)
        end

        return body if body
        uri = redirect_target(uri, location.not_nil!)
      end

      raise Errors::DownloadFailed.new("Too many redirects downloading #{url}")
    end

    def redirect_target(from : URI, location : String) : URI
      target = from.resolve(location)

      if from.scheme == "https" && target.scheme != "https"
        raise Errors::DownloadFailed.new("Refusing to follow a redirect from #{from} to non-HTTPS #{target}")
      end

      target
    end

    private def get(uri : URI, &)
      client = HTTP::Client.new(uri)
      client.connect_timeout = 10.seconds
      client.read_timeout = 60.seconds

      begin
        client.get(uri.request_target) { |response| yield response }
      ensure
        client.close
      end
    rescue ex : IO::Error
      raise Errors::DownloadFailed.new("Could not download #{uri}: #{ex.message}")
    end

    private def read_limited(io : IO, uri : URI) : Bytes
      buffer = IO::Memory.new

      if IO.copy(io, buffer, MAX_BYTES + 1) > MAX_BYTES
        raise Errors::DownloadFailed.new("#{uri} is larger than #{MAX_BYTES // 1024 // 1024} MB")
      end

      buffer.to_slice
    end
  end
end
