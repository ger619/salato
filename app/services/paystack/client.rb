require 'net/http'
require 'json'
require 'uri'

module Paystack
  class Client
    BASE_URL = 'https://api.paystack.co'.freeze

    def initialize
      @secret_key = ENV.fetch('PAYSTACK_SECRET_KEY')
    end

    def initialize_transaction(
      email:,
      amount:,
      reference:,
      callback_url:,
      metadata: {}
    )
      post(
        '/transaction/initialize',
        {
          email: email,
          amount: amount,
          currency: ENV.fetch('PAYSTACK_CURRENCY', 'KES'),
          reference: reference,
          callback_url: callback_url,
          metadata: metadata
        }
      )
    end

    def verify_transaction(reference)
      get("/transaction/verify/#{URI.encode_www_form_component(reference)}")
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
