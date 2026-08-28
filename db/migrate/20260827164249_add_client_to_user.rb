class AddClientToUser < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :client, null: true, foreign_key: true, type: :uuid
  end
end
