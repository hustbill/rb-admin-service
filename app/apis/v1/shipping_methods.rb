module V1
  class ShippingMethods < ::BaseAPI
    version 'v1', using: :path
    namespace "admin" do
      
      get 'shippingmethods' do
        #shipping_methods = ShippingMethod.where("zone_id in (select t1.zone_id from zone_members t1, countries t2 where t1.zoneable_id = t2.id and t1.zoneable_type = 'Country' and t2.is_clientactive is true)").map(&:decorated_attributes)
        shipping_methods = ShippingMethod.where(display_on: nil).map(&:decorated_attributes)
        #currencies = Currency.where("")
        res = {
          "shipping_methods" => shipping_methods,
          #"currencies" => currencies
        }
        generate_success_response(res)
      end

      put 'shippingmethods' do
        preference = Preference.find(params[:id])
        if preference.update_attribute(:value, params[:value])
          generate_success_response("ok")
        else
          generate_error_response("update failed")
        end
      end

      
    end #namespace admin
  end
end
