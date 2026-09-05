class AddClientToEvents < ActiveRecord::Migration[8.1]
  def up
    add_reference :events, :client, type: :uuid, foreign_key: true, index: true

    execute <<~SQL
      UPDATE events
      SET client_id = users.client_id
      FROM users
      WHERE events.user_id = users.id
          AND users.client_id IS NOT NULL;
    SQL
  end

  def down
    remove_reference :events, :client, foreign_key: true, index: true
  end
end
