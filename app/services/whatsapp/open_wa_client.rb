module Whatsapp
  class OpenWaClient
    class Error < StandardError; end

    # Set OPENWA_SEND_PATH in .env once you know the real route,
    # e.g. "api/messages/text" or "api/sendText".
    SEND_PATH = ENV.fetch('OPENWA_SEND_PATH', 'api/sendText')

    def self.endpoint(path)
      base = ENV.fetch('OPENWA_BASE_URL').chomp('/')
      URI.parse("#{base}/#{path.delete_prefix('/')}")
    end

    def self.send_text(to:, text:)
      uri = endpoint(SEND_PATH)

      response = Net::HTTP.post(
        uri,
        { args: { to: "#{to}@c.us", content: text } }.to_json,
        'Content-Type' => 'application/json',
        'api_key' => ENV.fetch('OPENWA_API_KEY'),
        'Authorization' => "Bearer #{ENV.fetch('OPENWA_API_KEY')}"
      )

      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "OpenWA #{response.code} at #{uri}: #{response.body.to_s.truncate(200)}"
      end

      JSON.parse(response.body)
    end
  end
end