class AllowUserDeletionWithEvents < ActiveRecord::Migration[8.1]
  def change
    change_column_null :events, :user_id, true

    remove_foreign_key :events, :users
    add_foreign_key :events, :users, on_delete: :nullify
  end
end
