class OrderReference
  def self.generate
    "EVT-#{Time.current.strftime('%Y%m%d%H%M%S')}-#{SecureRandom.hex(8).upcase}"
  end
end
