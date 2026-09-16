class AddPayotMethodToClient < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :payout_method, :string
  end
end
