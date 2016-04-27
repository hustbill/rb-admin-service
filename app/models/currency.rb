class Currency < ActiveRecord::Base
  has_one :country
  has_one :order
  has_one :client_fxrate
end