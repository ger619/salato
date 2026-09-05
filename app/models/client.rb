class Client < ApplicationRecord
  has_many :users, dependent: :nullify
  has_many :events, dependent: :restrict_with_error
  has_many :orders, through: :events
  has_one_attached :logo
  has_rich_text :description

  validates :name, presence: true
  validates :percentage_charge,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
            allow_nil: true

  before_validation :set_default_percentage_charge
  before_save :sync_paystack_subaccount, if: :should_sync_paystack_subaccount?

  def subaccount_ready?
    settlement_bank.present? && account_number.present?
  end

  def sync_paystack_subaccount!
    return unless subaccount_ready?

    paystack = Paystack::Client.new

    plain_desc = description.respond_to?(:to_plain_text) ? description.to_plain_text.presence : description.to_s.presence
    if paystack_subaccount_code.blank?
      response = paystack.create_subaccount(
        business_name: name,
        settlement_bank: settlement_bank,
        account_number: account_number,
        percentage_charge: percentage_charge,
        description: plain_desc,
        primary_contact_email: email,
        primary_contact_phone: phone
      )
      self.paystack_subaccount_code = response.dig('data', 'subaccount_code')
    else
      paystack.update_subaccount(
        subaccount_code: paystack_subaccount_code,
        business_name: name,
        settlement_bank: settlement_bank,
        account_number: account_number,
        percentage_charge: percentage_charge,
        description: plain_desc,
        primary_contact_email: email,
        primary_contact_phone: phone
      )
    end
  end

  def sync_paystack_subaccount
    sync_paystack_subaccount!
  rescue StandardError => e
    Rails.logger.error("Failed to sync Paystack subaccount for Client #{id || name}: #{e.message}")
  end

  private

  def set_default_percentage_charge
    self.percentage_charge ||= 0.0
  end

  def should_sync_paystack_subaccount?
    return false unless subaccount_ready?

    paystack_subaccount_code.blank? ||
      will_save_change_to_settlement_bank? ||
      will_save_change_to_account_number? ||
      will_save_change_to_name? ||
      will_save_change_to_percentage_charge? ||
      will_save_change_to_email? ||
      will_save_change_to_phone?
  end
end
