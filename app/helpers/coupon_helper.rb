module CouponHelper
  def build_response_coupons(collection, total)
    coupons_count = total
    {
      "meta" => {
        :count => coupons_count,
        :limit => params[:limit],
        :offset => params[:offset]
      },
      "coupons" => collection.map{|c| c.decorated_attributes.merge(product_group: c.product_group.try(:name)) }
    }
  end
end
