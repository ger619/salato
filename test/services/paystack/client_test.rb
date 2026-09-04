require 'test_helper'

module Paystack
  class ClientTest < ActiveSupport::TestCase
    class FakePaystackClient < Paystack::Client
      attr_accessor :last_request, :mock_response

      def perform_request(uri, request)
        @last_request = { uri: uri, request: request, body: request.body ? JSON.parse(request.body) : nil }
        @mock_response
      end
    end

    def make_success_response(body_hash)
      res = Net::HTTPSuccess.new('1.1', '200', 'OK')
      res.instance_variable_set(:@mock_body, body_hash.to_json)
      def res.body
        @mock_body
      end
      res
    end

    setup do
      @client = FakePaystackClient.new(secret_key: 'sk_test_mock_key')
    end

    test 'initialize_transaction passes subaccount and currency' do
      @client.mock_response = make_success_response({
                                                      status: true,
                                                      message: 'Authorization URL created',
                                                      data: {
                                                        authorization_url: 'https://checkout.paystack.com/mock-auth',
                                                        access_code: 'mock_code',
                                                        reference: 'SALATO-123'
                                                      }
                                                    })

      res = @client.initialize_transaction(
        email: 'buyer@example.com',
        amount: 50_000,
        reference: 'SALATO-123',
        callback_url: 'https://example.com/callback',
        subaccount: 'ACCT_test123'
      )

      assert res['status']
      assert_equal 'https://checkout.paystack.com/mock-auth', res.dig('data', 'authorization_url')
      assert_equal 'ACCT_test123', @client.last_request[:body]['subaccount']
    end

    test 'create_subaccount formats payload and returns subaccount code' do
      @client.mock_response = make_success_response({
                                                      status: true,
                                                      message: 'Subaccount created',
                                                      data: {
                                                        subaccount_code: 'ACCT_xyz789',
                                                        business_name: 'Organizer LLC',
                                                        settlement_bank: '044',
                                                        account_number: '0123456789',
                                                        percentage_charge: 5.0
                                                      }
                                                    })

      res = @client.create_subaccount(
        business_name: 'Organizer LLC',
        settlement_bank: '044',
        account_number: '0123456789',
        percentage_charge: 5.0,
        primary_contact_email: 'org@example.com'
      )

      assert_equal 'ACCT_xyz789', res.dig('data', 'subaccount_code')
      assert_equal 5.0, res.dig('data', 'percentage_charge')
      assert_equal 'Organizer LLC', @client.last_request[:body]['business_name']
      assert_equal '044', @client.last_request[:body]['settlement_bank']
      assert_equal '0123456789', @client.last_request[:body]['account_number']
      assert_equal 5.0, @client.last_request[:body]['percentage_charge']
    end

    test 'update_subaccount formats update payload' do
      @client.mock_response = make_success_response({
                                                      status: true,
                                                      message: 'Subaccount updated',
                                                      data: {
                                                        subaccount_code: 'ACCT_xyz789',
                                                        business_name: 'Organizer LLC Updated',
                                                        percentage_charge: 7.5
                                                      }
                                                    })

      res = @client.update_subaccount(
        subaccount_code: 'ACCT_xyz789',
        business_name: 'Organizer LLC Updated',
        percentage_charge: 7.5
      )

      assert_equal 'ACCT_xyz789', res.dig('data', 'subaccount_code')
      assert_equal 7.5, res.dig('data', 'percentage_charge')
      assert_equal 'Organizer LLC Updated', @client.last_request[:body]['business_name']
      assert_equal 7.5, @client.last_request[:body]['percentage_charge']
    end
  end
end
