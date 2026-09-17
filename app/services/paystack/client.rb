require 'net/http'
require 'json'
require 'uri'

module Paystack
  # Carries the whole response so callers (and the log) can see WHY a call
  # failed. Paystack puts the real reason in data.message, not in the
  # top-level message, which is usually just "Charge attempted".
  class Error < StandardError
    attr_reader :http_status, :body

    def initialize(message, http_status: nil, body: nil)
      super(message)
      @http_status = http_status
      @body = body.is_a?(Hash) ? body : {}
    end

    def data
      body['data'].is_a?(Hash) ? body['data'] : {}
    end

    # The most specific reason Paystack gave us.
    def reason
      data['message'].presence ||
        data['gateway_response'].presence ||
        body['message'].presence ||
        message
    end

    def to_log
      "#{message} (HTTP #{http_status}) #{body.to_json}"
    end
  end

  class Client
    BASE_URL = 'https://api.paystack.co'.freeze
    OPEN_TIMEOUT = 5 # seconds to connect
    READ_TIMEOUT = 20 # seconds to wait for a response

    def initialize(secret_key: nil)
      @secret_key = secret_key || ENV.fetch('PAYSTACK_SECRET_KEY')
    end

    # ── Transactions ─────────────────────────────────────────────

    # channels: limits what Paystack's checkout offers, e.g. %w[card].
    # Pass nil to let Paystack offer every channel enabled on the account —
    # safer than forcing a channel that may not be active.
    def initialize_transaction(
      email:,
      amount:,
      reference:,
      callback_url:,
      subaccount: nil,
      transaction_charge: nil,
      bearer: nil,
      channels: nil,
      metadata: {}
    )
      payload = {
        email: email,
        amount: amount,
        currency: currency,
        reference: reference,
        callback_url: callback_url,
        metadata: metadata
      }
      payload[:subaccount] = subaccount if subaccount.present?
      payload[:transaction_charge] = transaction_charge if transaction_charge.present?
      payload[:bearer] = bearer if bearer.present?
      payload[:channels] = Array(channels) if channels.present?

      post('/transaction/initialize', payload)
    end

    def verify_transaction(reference)
      get("/transaction/verify/#{URI.encode_www_form_component(reference)}")
    end

    # ── Charges ──────────────────────────────────────────────────

    # Sends a mobile money prompt straight to the customer's phone.
    # provider: 'mpesa' (M-Pesa) or 'atl' (Airtel Money).
    # phone: international format, e.g. '+254712345678'.
    #
    # Returns the parsed body in every case where Paystack gave us a usable
    # data object — including a failed charge, where the body looks like:
    #
    #   { "status": false, "message": "Charge attempted",
    #     "data": { "status": "failed", "message": "Insufficient funds" } }
    #
    # The caller branches on data["status"]: "success", "failed",
    # "pay_offline", "send_otp", "pending". Only a genuinely broken call
    # (auth, validation, no active channel, Paystack 5xx) raises.
    def charge_mobile_money(
      email:,
      amount:,
      phone:,
      provider:,
      reference:,
      subaccount: nil,
      metadata: {}
    )
      payload = {
        email: email,
        amount: amount,
        currency: currency,
        reference: reference,
        mobile_money: { phone: phone, provider: provider },
        metadata: metadata
      }
      payload[:subaccount] = subaccount if subaccount.present?

      post('/charge', payload, tolerate_charge_failure: true)
    end

    # Paystack recommends re-checking a charge that came back pending.
    def check_pending_charge(reference)
      get("/charge/#{URI.encode_www_form_component(reference)}")
    end

    # ── Subaccounts ──────────────────────────────────────────────

    def create_subaccount(
      business_name:,
      settlement_bank:,
      account_number:,
      percentage_charge: nil,
      description: nil,
      primary_contact_email: nil,
      primary_contact_name: nil,
      primary_contact_phone: nil,
      metadata: {}
    )
      payload = {
        business_name: business_name,
        settlement_bank: settlement_bank,
        account_number: account_number
      }
      payload[:percentage_charge] = percentage_charge.to_f if percentage_charge.present?
      payload[:description] = description if description.present?
      payload[:primary_contact_email] = primary_contact_email if primary_contact_email.present?
      payload[:primary_contact_name] = primary_contact_name if primary_contact_name.present?
      payload[:primary_contact_phone] = primary_contact_phone if primary_contact_phone.present?
      payload[:metadata] = metadata if metadata.present?

      post('/subaccount', payload)
    end

    def update_subaccount(
      subaccount_code:,
      business_name: nil,
      settlement_bank: nil,
      account_number: nil,
      percentage_charge: nil,
      description: nil,
      primary_contact_email: nil,
      primary_contact_name: nil,
      primary_contact_phone: nil,
      metadata: {}
    )
      payload = {}
      payload[:business_name] = business_name if business_name.present?
      payload[:settlement_bank] = settlement_bank if settlement_bank.present?
      payload[:account_number] = account_number if account_number.present?
      payload[:percentage_charge] = percentage_charge.to_f unless percentage_charge.nil?
      payload[:description] = description if description.present?
      payload[:primary_contact_email] = primary_contact_email if primary_contact_email.present?
      payload[:primary_contact_name] = primary_contact_name if primary_contact_name.present?
      payload[:primary_contact_phone] = primary_contact_phone if primary_contact_phone.present?
      payload[:metadata] = metadata if metadata.present?

      put("/subaccount/#{URI.encode_www_form_component(subaccount_code)}", payload)
    end

    def fetch_subaccount(subaccount_code)
      get("/subaccount/#{URI.encode_www_form_component(subaccount_code)}")
    end

    def list_subaccounts(per_page: 50, page: 1)
      get("/subaccount?per_page=#{per_page}&page=#{page}")
    end

    # ── Miscellaneous ────────────────────────────────────────────

    def list_banks(country: nil, currency: nil)
      params = []
      params << "country=#{URI.encode_www_form_component(country)}" if country.present?
      params << "currency=#{URI.encode_www_form_component(currency)}" if currency.present?
      query = params.empty? ? '' : "?#{params.join('&')}"

      get("/bank#{query}")
    end

    private

    def currency
      ENV.fetch('PAYSTACK_CURRENCY', 'KES')
    end

    def post(path, payload, tolerate_charge_failure: false)
      send_request(Net::HTTP::Post, path, payload,
                   tolerate_charge_failure: tolerate_charge_failure)
    end

    def put(path, payload)
      send_request(Net::HTTP::Put, path, payload)
    end

    def get(path)
      send_request(Net::HTTP::Get, path)
    end

    def send_request(request_class, path, payload = nil, tolerate_charge_failure: false)
      uri = URI("#{BASE_URL}#{path}")

      request = request_class.new(uri)
      request['Authorization'] = "Bearer #{@secret_key}"
      request['Content-Type'] = 'application/json'
      request.body = payload.to_json if payload

      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: true,
        open_timeout: OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT
      ) do |http|
        http.request(request)
      end

      parse_response(response, path, tolerate_charge_failure: tolerate_charge_failure)
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
      raise Paystack::Error.new("Paystack unreachable: #{e.class}")
    end

    def parse_response(response, path, tolerate_charge_failure: false)
      body = JSON.parse(response.body)

      unless body.is_a?(Hash)
        raise Paystack::Error.new(
          "Paystack returned an unexpected payload (HTTP #{response.code})",
          http_status: response.code.to_i
        )
      end

      # The normal happy path.
      return body if response.is_a?(Net::HTTPSuccess) && body['status']

      data = body['data']

      # A charge that was attempted and resolved (usually to "failed"). The
      # outer status is false but data carries the real outcome, so hand it
      # back and let the caller decide what to tell the buyer.
      if tolerate_charge_failure && data.is_a?(Hash) && data['status'].present?
        Rails.logger.warn(
          "Paystack #{path} returned #{data['status']}: #{body.to_json}"
        )
        return body
      end

      detail = data.is_a?(Hash) ? (data['message'].presence || data['gateway_response'].presence) : nil
      summary = [body['message'].presence, detail].compact.join(' — ')

      raise Paystack::Error.new(
        summary.presence || "Paystack error (HTTP #{response.code})",
        http_status: response.code.to_i,
        body: body
      )
    rescue JSON::ParserError
      raise Paystack::Error.new(
        "Paystack returned an invalid response (HTTP #{response.code})",
        http_status: response.code.to_i
      )
    end
  end
end
