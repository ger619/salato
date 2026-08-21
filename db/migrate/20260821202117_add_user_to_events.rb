class AddUserToEvents < ActiveRecord::Migration[8.1]
  def change
    add_reference :events, :user, null: true, foreign_key: true, type: :uuid
  end
end
