class AutoshipPayment < ActiveRecord::Base
  belongs_to :autoship
  belongs_to :creditcard

  accepts_nested_attributes_for :creditcard, :allow_destroy => true
  scope :active, -> { where(active: true) }
  scope :active_payment, -> { active.first }

  before_create :other_payments_to_inactive, if: ->(payment) { payment.active }

  def other_payments_to_inactive
    AutoshipPayment.where(autoship_id: self.autoship_id).active.update_all(active: false)
  end
end
