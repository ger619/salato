class RemoveDetailsFromClient < ActiveRecord::Migration[8.1]
  def change
    remove_column :clients, :website, :string, if_exists: true
    remove_column :clients, :settlement_bank, :string, if_exists: true
    remove_column :clients, :tax_pin, :string, if_exists: true
  end
end