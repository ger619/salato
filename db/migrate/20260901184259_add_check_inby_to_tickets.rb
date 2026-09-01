class AddCheckInbyToTickets < ActiveRecord::Migration[8.1]
  def change
    add_reference :tickets, :checked_in_by, foreign_key: { to_table: :users }, type: :uuid, index: true
  end
end
