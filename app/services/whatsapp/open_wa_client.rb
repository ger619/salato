module Whatsapp
  class OpenWaClient
    class Error < StandardError; end

    def self.send_text(to:, text:)
      session_id = ENV.fetch('OPENWA_SESSION_ID')
      uri = URI.join(ENV.fetch('OPENWA_BASE_URL'), "/api/sessions/#{session_id}/messages/send-text")

      response = Net::HTTP.post(
        uri,
        { chatId: "#{to}@c.us", text: text }.to_json,
        'Content-Type' => 'application/json',
        'X-API-Key' => ENV.fetch('OPENWA_API_KEY')
      )

      raise Error, "OpenWA #{response.code}: #{response.body.to_s.truncate(200)}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end
  end
end
