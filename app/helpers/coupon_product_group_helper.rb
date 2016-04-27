module CouponProductGroupHelper
  def build_response_groups(collection, total)
    groups_count = total
    groups = collection.each(&:decorated_attributes)
    {
      "meta" => {
        :count => groups_count,
        :limit => params[:limit],
        :offset => params[:offset]
      },
      "groups" => groups
    }
  end
end