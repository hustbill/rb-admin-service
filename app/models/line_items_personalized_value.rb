class LineItemsPersonalizedValue < ActiveRecord::Base
  
  belongs_to :line_item
  belongs_to :personalized_type
  
  def personalized_name
    personalized_type.name
  end
  
end