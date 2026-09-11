class AddWhatsappSentAtToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :whatsapp_sent_at, :datetime
  end
end
