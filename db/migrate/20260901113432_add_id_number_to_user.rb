class AddIdNumberToUser < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :id_number, :string
    add_column :users, :status, :boolean, default: false
  end
end
