class AddMobileMoneyProviderToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :mobile_money_provider, :string
  end
end
