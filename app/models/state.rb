class State < ActiveRecord::Base
  belongs_to :country
  belongs_to :address
  validates :country, :name, :presence => true

  scope :active, -> { where(active: true) }
end

