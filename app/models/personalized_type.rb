class PersonalizedType < ActiveRecord::Base

  validates :name, presence: true
  validates_uniqueness_of :name

  has_many :personalized_types_products
  has_many :line_items_personalized_values
  
  before_save :set_column_value


  private

  def set_column_value
    self.active = true
    self.localization_key = self.name.gsub(/\s/, '_')
  end

end