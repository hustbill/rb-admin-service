class Calculator < ActiveRecord::Base

  belongs_to :calculable
  has_many :preferences, :as => :owner

  self.inheritance_column = :_type_disabled

  def decorated_attributes
  {
    'preferences' => preferences.delete_if{|p| p.name == 'currency_id'}.map(&:decorated_attributes),
    'type' => self.type
  }
  end
end

