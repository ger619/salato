require 'net/http'
require 'json'
require 'uri'

module Paystack
  class Error < StandardError; end

  class Client
    BASE_URL = 'https://api.paystack.co'.freeze
    OPEN_TIMEOUT = 5 # seconds to connect
    READ_TIMEOUT = 20 # seconds to wait for a response

    def initialize(secret_key: nil)
      @secret_key = secret_key || ENV.fetch('PAYSTACK_SECRET_KEY')
    end

    # ── Transactions ─────────────────────────────────────────────

    # channels: limits what Paystack's checkout offers, e.g. %w[card].
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
      payload[:channels] = channels if channels.present?

      post('/transaction/initialize', payload)
    end

    def verify_transaction(reference)
      get("/transaction/verify/#{URI.encode_www_form_component(reference)}")
    end

    # ── Charges ──────────────────────────────────────────────────

    # Sends a mobile money prompt straight to the customer's phone.
    # provider: 'mpesa' (M-Pesa) or 'atl' (Airtel Money).
    # phone: international format, e.g. '+254712345678'.
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

      post('/charge', payload)
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

    def post(path, payload)
      send_request(Net::HTTP::Post, path, payload)
    end

    def put(path, payload)
      send_request(Net::HTTP::Put, path, payload)
    end

    def get(path)
      send_request(Net::HTTP::Get, path)
    end

    def send_request(request_class, path, payload = nil)
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

      parse_response(response)
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
      raise Paystack::Error, "Paystack unreachable: #{e.class}"
    end

    def parse_response(response)
      body = JSON.parse(response.body)

      raise Paystack::Error, "Paystack error: #{body['message'] || response.code}" unless response.is_a?(Net::HTTPSuccess) && body['status']

      body
    rescue JSON::ParserError
      raise Paystack::Error, "Paystack returned an invalid response (HTTP #{response.code})"
    end
  end
end
