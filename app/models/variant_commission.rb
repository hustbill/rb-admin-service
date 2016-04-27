class VariantCommission < ActiveRecord::Base
  belongs_to :variant
  belongs_to :variant_commission_type

  validate :variant_id, :volume, presence: true
  validates_numericality_of :volume

end
