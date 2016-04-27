class OrdersCoupon < ActiveRecord::Base
  belongs_to :coupon
  belongs_to :order

  def records
    result = []
    records = JSON.parse(details)
    return [] unless records['lineItems'].present?
    records['lineItems'].each do |record|
    c = Catalog.find_by(code: record['catalogCode'])
    v = Variant.find(record['variantId'])
    p = v.product
    u = order.user
    r = u.roles.first
    cp = CatalogProduct.find_by(role_id: r.id, catalog_id: c.id, product_id: p.id)
    cpv = CatalogProductVariant.find_by(variant_id: record['variantId'], catalog_product_id: cp.id)
    result << {
      product_name: p.try(:name),
      variant_sku: v.sku,
      bonus_type: coupon.description,
      order_id: order_id,
      user_name: u.try(:name),
      distributor_id: u.distributor.id,
      retail_price: cpv.price,
      quantity: record['quantity']
    }
    end
    result
  end

  def amount
    JSON.parse(details)['lineItems'] && JSON.parse(details)['lineItems'].count || 0
  end
end
