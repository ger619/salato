class CreateBroadcasts < ActiveRecord::Migration[8.1]
  def change
    create_table :broadcasts, id: :uuid do |t|
      t.references :event, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.text :message
      t.jsonb :filters
      t.string :status,  default: "pending", null: false
      t.integer :total_count,  default: 0, null: false
      t.integer :sent_count,   default: 0, null: false
      t.integer :failed_count, default: 0, null: false

      t.timestamps
    end
  end
end
