class AddBankToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :bank, :string
  end
end
