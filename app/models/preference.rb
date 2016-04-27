class Preference < ActiveRecord::Base

  belongs_to :owner
  belongs_to :calculator, foreign_key: :group_id, class_name: 'Calculator'
  scope :autoship_adjustment_labels, ->{ where(owner_type: 'ManualAutoshipAdjustment', owner_id: 1).order('id asc') }
  scope :order_adjustment_labels, ->{ where(owner_type: 'ManualOrderAdjustment', owner_id: 1).order('id asc') }
  scope :coupon_types, ->{where(owner_type: 'CouponType', owner_id: 1).order('value')}
  def decorated_attributes
  {
    'id' => id,
    'name' => name,
    'value' => value
  }
  end
end

