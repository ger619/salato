require 'test_helper'

class ClientTest < ActiveSupport::TestCase
  test 'validates presence of name' do
    client = Client.new(name: nil)
    assert_not client.valid?
    assert_includes client.errors[:name], "can't be blank"
  end

  test 'defaults percentage_charge to 0.0' do
    client = Client.new(name: 'Test Client')
    client.valid?
    assert_equal 0.0, client.percentage_charge
  end

  test 'validates percentage_charge is between 0 and 100' do
    client = Client.new(name: 'Test Client', percentage_charge: -5)
    assert_not client.valid?
    assert_includes client.errors[:percentage_charge], 'must be greater than or equal to 0'

    client.percentage_charge = 150
    assert_not client.valid?
    assert_includes client.errors[:percentage_charge], 'must be less than or equal to 100'

    client.percentage_charge = 12.5
    assert client.valid?
  end

  test 'subaccount_ready? returns true only when settlement_bank and account_number exist' do
    client = Client.new(name: 'Test Client')
    assert_not client.subaccount_ready?

    client.settlement_bank = '044'
    assert_not client.subaccount_ready?

    client.account_number = '0123456789'
    assert client.subaccount_ready?
  end

  def with_stubbed_paystack(fake_client)
    singleton_class = class << Paystack::Client; self; end
    orig_new = Paystack::Client.method(:new)
    singleton_class.send(:define_method, :new) { |**_args| fake_client }
    yield
  ensure
    singleton_class.send(:define_method, :new, orig_new)
  end

  test 'sync_paystack_subaccount! creates subaccount when code is blank' do
    client = Client.new(
      name: 'Test Client',
      email: 'client@example.com',
      phone: '+254700000000',
      settlement_bank: '044',
      account_number: '0123456789',
      percentage_charge: 5.0
    )

    fake_client = Object.new
    def fake_client.create_subaccount(**params)
      {
        'status' => true,
        'data' => {
          'subaccount_code' => 'ACCT_generated123',
          'percentage_charge' => params[:percentage_charge]
        }
      }
    end

    with_stubbed_paystack(fake_client) do
      client.sync_paystack_subaccount!
      assert_equal 'ACCT_generated123', client.paystack_subaccount_code
    end
  end

  test 'sync_paystack_subaccount! updates subaccount when code is present' do
    client = Client.new(
      name: 'Test Client Updated',
      paystack_subaccount_code: 'ACCT_existing123',
      settlement_bank: '044',
      account_number: '0123456789',
      percentage_charge: 10.0
    )

    updated_params = nil
    fake_client = Object.new
    fake_client.define_singleton_method(:update_subaccount) do |**params|
      updated_params = params
      { 'status' => true, 'data' => { 'subaccount_code' => params[:subaccount_code] } }
    end

    with_stubbed_paystack(fake_client) do
      client.sync_paystack_subaccount!
      assert_equal 'ACCT_existing123', updated_params[:subaccount_code]
      assert_equal 10.0, updated_params[:percentage_charge]
      assert_equal 'Test Client Updated', updated_params[:business_name]
    end
  end
end
