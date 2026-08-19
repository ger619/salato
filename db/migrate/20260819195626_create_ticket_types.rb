class CreateTicketTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :ticket_types, id: :uuid do |t|
      t.references :event, null: false, foreign_key: true, type: :uuid

      t.string :name
      t.string :description
      t.decimal :price, precision: 12, scale: 2, null: false
      t.integer :quantity, null: false, default: 0
      t.integer :reserved_quantity, null: false, default: 0
      t.integer :sold_quantity, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
