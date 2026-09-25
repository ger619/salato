class CreateBroadcastDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :broadcast_deliveries, id: :uuid do |t|
      t.references :broadcast, null: false, foreign_key: true, type: :uuid
      t.references :ticket, null: false, foreign_key: true, type: :uuid
      t.string :phone
      t.string :status
      t.text :error
      t.datetime :sent_at

      t.timestamps
    end
  end
end
