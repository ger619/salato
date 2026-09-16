class RemoveDetailsFromClient < ActiveRecord::Migration[8.1]
  def change
    remove_column :clients, :website, :string if exists_column?(:clients, :website)
    remove_column :clients, :settlement_bank, :string if exists_column?(:clients, :settlement_bank)
    remove_column :clients, :tax_pin, :string if exists_column?(:clients, :tax_pin)
  end
end