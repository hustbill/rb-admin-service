class ProductOptionType < ActiveRecord::Base

  belongs_to :product
  belongs_to :option_type

  scope :get_by_ids, ->(product_id, option_type_id) { where(product_id: product_id, option_type_id: option_type_id) }

end