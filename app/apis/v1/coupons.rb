module V1
  class Coupons < ::BaseAPI
    version 'v1', using: :path
    namespace 'admin' do
      helpers CouponHelper
      resource 'coupons' do
        params do
          optional :limit, :type => Integer, :default => 25
          optional :offset, :type => Integer, :default => 0
          optional :code, :type => String, :default => nil
        end
        get do
          search = ::Coupon
            .search(params[:q])
            .result
            .order("coupons.id desc")
          coupons = search.limit(params[:limit]).offset(params[:offset])
          generate_success_response( build_response_coupons(coupons, search.count) )
        end

        desc 'get coupon type'
        get 'get_coupon_type' do
          generate_success_response(Preference.coupon_types.map(&:attributes))
        end

        params do
          requires :id, :type => Integer
        end
        get ':id' do
          coupon = Coupon.find_by(id: params["id"])
          generate_success_response( coupon: coupon.decorated_attributes )
        end

        params do
          requires :id, :type => Integer
        end
        delete ':id' do
          coupon = Coupon.find_by(id: params["id"])
          coupon.destroy
          generate_success_response( "ok" )
        end

        params do
          requires :id, :type => Integer
          requires :coupon
        end
        put ':id' do
          coupon = Coupon.find_by(id: params["id"])
          coupon.active         = !params[:coupon][:active].nil?
          params[:rules][:allow_all_products] = true if params[:coupon][:coupon_type] == 'Buying Bonus'
          if params[:distributor_id].present?
            dd = Distributor.find_by(id: params[:distributor_id])
            if dd
              coupon.user_id = dd.user_id
              coupon.is_single_user = true
            else
              coupon.user_id = nil
              coupon.is_single_user = false
            end
          else
            coupon.user_id = nil
            coupon.is_single_user = false
          end
          if coupon.update(params[:coupon]) and coupon.update_rules(params[:rules])
            generate_success_response("ok")
          else
            return_error_response( coupon.errors.full_messages.join(", ") )
          end
        end

        params do
          requires :coupon
        end
        post do
          coupon = Coupon.new params[:coupon]
          coupon.active         = !params[:coupon][:active].nil?
          params[:rules][:allow_all_products] = true if params[:coupon][:coupon_type] == 'Buying Bonus'
          if params[:distributor_id].present?
            dd = Distributor.find_by(id: params[:distributor_id])
            if dd
              coupon.user_id = dd.user_id
              coupon.is_single_user = true
            else
              coupon.user_id = nil
              coupon.is_single_user = false
            end
          else
            coupon.user_id = nil
            coupon.is_single_user = false
          end
          if coupon.save and coupon.update_rules(params[:rules])
            generate_success_response(coupon.decorated_attributes)
          else
            return_error_response(coupon.errors.full_messages.join(', '))
          end
        end

        params do
          requires :coupon
        end
        post 'create_party_coupon' do
          coupon = Coupon.new params[:coupon]
          coupon.active         = true
          coupon.is_single_user = true
          if coupon.save and coupon.update_rules(params[:rules])
            generate_success_response(coupon.decorated_attributes)
          else
            return_error_response(coupon.errors.full_messages.join(', '))
          end
        end

        params do
          requires :party_id
        end
        get 'rewards/get' do
          event = EventReward.find_by(event_code: params[:party_id])
          # coupons = event && event.coupons
          generate_success_response( event.decorated_attributes )
        end

        params do
          requires :code
        end
        post 'rewards/create' do
          result = EventReward.create_party_rewards(params[:code], params[:variant_id], params[:host_email])
          case result
          when 'ok'
            generate_success_response( result )
          else
            return_error_response( result )
          end
        end

        desc 'check exist code'
        get 'exist/:code' do
          coupon = Coupon.find_by code: params[:code].to_s
          if coupon
            generate_success_response(true)
          else
            generate_success_response(false)
          end
        end

      end
    end
  end
end
