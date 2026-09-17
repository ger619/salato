class AddPaystackReferenceToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :paystack_reference, :string
    add_index :orders, :paystack_reference
  end
end
