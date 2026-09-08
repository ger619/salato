class AddEEventTypeToEvent < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :event_type, :string
  end
end
