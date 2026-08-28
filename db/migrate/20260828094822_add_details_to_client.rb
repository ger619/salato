class AddDetailsToClient < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :website, :string
    add_column :clients, :country, :string
    add_column :clients, :city, :string
    add_column :clients, :registration_number, :string
    add_column :clients, :tax_pin, :string
    add_column :clients, :description, :text
    add_column :clients, :settlement_bank, :string
    add_column :clients, :account_number, :string
    add_column :clients, :paystack_subaccount_code, :string
  end
end
