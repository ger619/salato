class RemoveDetailsFromClient < ActiveRecord::Migration[8.1]
  def change
    remove_column :clients, :website, :string
    remove_column :clients, :settlement_bank, :string
    remove_column :clients, :tax_pin, :string
  end
end