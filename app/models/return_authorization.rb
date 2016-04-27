class ReturnAuthorization < ActiveRecord::Base
  
  belongs_to :order
  has_many :inventory_units
  before_create :generate_number
  before_save :force_positive_amount

  validates :order, :presence => true
  validates :amount, :numericality => true
  validate :must_have_shipped_units
  
  
end