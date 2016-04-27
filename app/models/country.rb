class Country < ActiveRecord::Base
  has_many :states
  has_and_belongs_to_many :products
  belongs_to :commission_currency, foreign_key: 'commission_currency_id', class_name: 'Currency'
  belongs_to :currency
  validates :name, :iso_name, :presence => true

  scope :all_clientactive, -> { where(is_clientactive: true).order('countries.name ASC') }
end
