class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events, id: :uuid do |t|
      t.string :name
      t.string :slug
      t.string :description
      t.string :venue
      t.datetime :start_at
      t.datetime :end_at
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :events, :slug, unique: true
  end
end
