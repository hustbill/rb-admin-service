class ClientFxrate < ActiveRecord::Base
  belongs_to :currency

  def self.exchange_rate (currency_id)
    return 1 if currency_id.nil?
    fx = ClientFxrate.find_by_currency_id(currency_id)
    return 1 if fx.nil?
    return fx['convert_rate']
  end

  def self.client_fxrate_hash
    h = {}
    ClientFxrate.all.each do |cf|
      h[cf.currency_id] = cf.convert_rate.to_f
    end
    h
  end
end