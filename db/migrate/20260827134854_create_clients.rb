class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients, id: :uuid do |t|
      t.string :name
      t.string :email
      t.string :phone
      t.text :address

      t.timestamps
    end
  end
end
