class CreateTickets < ActiveRecord::Migration[8.1]
  def change
    create_table :tickets, id: :uuid do |t|
      t.references :event, null: false, foreign_key: true, type: :uuid
      t.references :order, null: false, foreign_key: true, type: :uuid
      t.references :ticket_type, null: false, foreign_key: true, type: :uuid

      t.string :ticket_number, null: false
      t.string :attendee_name, null: false
      t.string :attendee_email, null: false

      t.string :qr_token, null: false
      t.string :status, null: false

      t.datetime :checked_in_at

      t.timestamps
    end

    add_index :tickets, :ticket_number, unique: true
    add_index :tickets, :qr_token, unique: true

  end
end
