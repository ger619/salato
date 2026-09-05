require 'net/http'
require 'json'
require 'uri'

module Paystack
  class Client
    BASE_URL = 'https://api.paystack.co'.freeze

    def initialize(secret_key: nil)
      @secret_key = secret_key || ENV.fetch('PAYSTACK_SECRET_KEY')
    end

    def initialize_transaction(
      email:,
      amount:,
      reference:,
      callback_url:,
      subaccount: nil,
      transaction_charge: nil,
      bearer: nil,
      metadata: {}
    )
      payload = {
        email: email,
        amount: amount,
        currency: ENV.fetch('PAYSTACK_CURRENCY', 'KES'),
        reference: reference,
        callback_url: callback_url,
        metadata: metadata
      }
      payload[:subaccount] = subaccount if subaccount.present?
      payload[:transaction_charge] = transaction_charge if transaction_charge.present?
      payload[:bearer] = bearer if bearer.present?

      post('/transaction/initialize', payload)
    end

    def verify_transaction(reference)
      get("/transaction/verify/#{URI.encode_www_form_component(reference)}")
    end

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

    def list_banks(country: nil, currency: nil)
      params = []
      params << "country=#{URI.encode_www_form_component(country)}" if country.present?
      params << "currency=#{URI.encode_www_form_component(currency)}" if currency.present?
      query = params.empty? ? '' : "?#{params.join('&')}"
      get("/bank#{query}")
    end

    private

    def post(path, payload)
      uri = URI("#{BASE_URL}#{path}")

      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{@secret_key}"
      request['Content-Type'] = 'application/json'
      request.body = payload.to_json

      response = perform_request(uri, request)

      parse_response(response)
    end

    def put(path, payload)
      uri = URI("#{BASE_URL}#{path}")

      request = Net::HTTP::Put.new(uri)
      request['Authorization'] = "Bearer #{@secret_key}"
      request['Content-Type'] = 'application/json'
      request.body = payload.to_json

      response = perform_request(uri, request)

      parse_response(response)
    end

    def get(path)
      uri = URI("#{BASE_URL}#{path}")

      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{@secret_key}"
      request['Content-Type'] = 'application/json'

      response = perform_request(uri, request)

      parse_response(response)
    end

    def perform_request(uri, request)
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == 'https'
      ) do |http|
        http.request(request)
      end
    end

    def parse_response(response)
      body = JSON.parse(response.body)

      raise "Paystack error: #{body['message']}" unless response.is_a?(Net::HTTPSuccess) && body['status']

      body
    end
  end
end
