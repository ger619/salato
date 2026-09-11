# app/services/whatsapp/client.rb
#
# Thin wrapper over a self-hosted OpenWA gateway (https://docs.open-wa.org).
# Same shape as Paystack::Client: Net::HTTP, no extra gems.
#
# Every call is POST /api/sessions/:session_id/messages/:action with an
# X-API-Key header.
#
# The four error classes are deliberate SIBLINGS, not a hierarchy, so the job
# can decide retry vs discard per class without worrying about which
# rescue_from handler wins:
#
#   Unavailable     - the request never reached WhatsApp. Safe to retry.
#   SessionNotReady - gateway up, session reconnecting (409). Safe to retry.
#   Error           - we sent something wrong (4xx). Retrying won't fix it.
#   AmbiguousSend   - 5xx or a read timeout. The message MAY already have been
#                     delivered. Never blind-retry: that is how one ticket
#                     becomes two in the buyer's chat.
require 'net/http'
require 'json'
require 'uri'

module Whatsapp
  class Client
    class Unavailable < StandardError
    end

    class SessionNotReady < StandardError
    end

    class Error < StandardError
    end

    class AmbiguousSend < StandardError
    end

    OPEN_TIMEOUT = 5

    # A document send uploads the PDF and waits on WhatsApp Web, so it is
    # slower than a plain API call.
    READ_TIMEOUT = 60

    def self.configured?
      ENV['OPENWA_BASE_URL'].present? &&
        ENV['OPENWA_API_KEY'].present? &&
        ENV['OPENWA_SESSION_ID'].present?
    end

    def initialize(base_url: nil, api_key: nil, session_id: nil)
      @base_url = (base_url || ENV.fetch('OPENWA_BASE_URL')).chomp('/')
      @api_key = api_key || ENV.fetch('OPENWA_API_KEY')
      @session_id = session_id || ENV.fetch('OPENWA_SESSION_ID')
    end

    def send_text(chat_id:, text:)
      post('send-text', chatId: chat_id, text: text)
    end

    # base64 must be raw base64 (no "data:" prefix), and mimetype is required
    # whenever base64 is used instead of url.
    def send_document(chat_id:, base64:, filename:, caption: nil, mimetype: 'application/pdf')
      payload = {
        chatId: chat_id,
        base64: base64,
        mimetype: mimetype,
        filename: filename
      }

      payload[:caption] = caption if caption.present?

      post('send-document', **payload)
    end

    private

    def post(action, **payload)
      uri = URI("#{@base_url}/api/sessions/#{@session_id}/messages/#{action}")

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['X-API-Key'] = @api_key
      request.body = payload.to_json

      response = Net::HTTP.start(
        uri.hostname,
        uri.port,
        use_ssl: uri.scheme == 'https',
        open_timeout: OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT
      ) { |http| http.request(request) }

      handle(response)
    rescue Net::ReadTimeout => e
      # The gateway took the request. We don't know what it did with it.
      raise AmbiguousSend, "OpenWA read timeout: #{e.message}"
    rescue Errno::ECONNREFUSED, Net::OpenTimeout, SocketError, EOFError => e
      raise Unavailable, "OpenWA unreachable: #{e.class}: #{e.message}"
    end

    def handle(response)
      code = response.code.to_i
      body = parse(response.body)

      return body if code.between?(200, 299)

      message = Array(body['message']).join(', ').presence || response.body.to_s.truncate(300)

      case code
      when 409 then raise SessionNotReady, "session not ready (409): #{message}"
      when 400..499 then raise Error, "OpenWA #{code}: #{message}"
      else raise AmbiguousSend, "OpenWA #{code}: #{message}"
      end
    end

    def parse(raw)
      JSON.parse(raw.presence || '{}')
    rescue JSON::ParserError
      {}
    end
  end
end
