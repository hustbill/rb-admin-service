class LegalEntity < ActiveRecord::Base
  has_many :warehouses

  belongs_to :address
  belongs_to :zone

  has_one :state, :through => :address
  has_one :country, :through => :address
end