class CouponProductGroupsProduct < ActiveRecord::Base
  belongs_to :product
  belongs_to :coupon_product_group

  def self.catalog_name(product_id, group_id)
    Catalog.find( CouponProductGroupsProduct.find_by(product_id: product_id, coupon_product_group_id: group_id).catalog_id ).name
  rescue
    ""
  end
end
