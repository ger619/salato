class CreateJoinTableEventsUsers < ActiveRecord::Migration[8.1]
  def change
    create_join_table :events, :users, column_options: { type: :uuid } do |t|
       t.index [:event_id, :user_id], unique: true
       t.index [:user_id, :event_id], unique: true
    end
  end
end
