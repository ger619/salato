class AddPercentageChargeToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :percentage_charge, :decimal, precision: 5, scale: 2, default: 0.0
  end
end
