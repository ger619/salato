class AddPaystackAccessCodeToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :paystack_access_code, :string
  end
end
