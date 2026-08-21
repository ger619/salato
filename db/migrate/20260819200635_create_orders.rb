class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders, id: :uuid do |t|
      t.references :event, null: false, foreign_key: true, type: :uuid
      t.references :ticket_type, null: false, foreign_key: true, type: :uuid

      t.string :reference, null: false

      t.string :customer_name, null: false
      t.string :customer_email, null: false
      t.string :customer_phone, null: false

      t.integer :quantity, null: false

      t.decimal :unit_price, precision: 12, scale: 2, null: false
      t.decimal :total_price, precision: 12, scale: 2, null: false

      t.string :currency, null: false, default: "KES"
      t.string :status, null: false, default: "pending"

      t.datetime :paid_at
      t.datetime :expires_at

      t.timestamps
    end
    add_index :orders, :reference, unique: true
    add_index :orders, :status
  end
end
