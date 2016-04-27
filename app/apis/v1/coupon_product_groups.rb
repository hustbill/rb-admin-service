module V1
  class CouponProductGroups < ::BaseAPI
    version 'v1', using: :path
    namespace 'admin' do
      helpers CouponProductGroupHelper
      resource 'coupon_product_groups' do
        params do
          optional :limit, :type => Integer, :default => 25
          optional :offset, :type => Integer, :default => 0
          optional :code, :type => String, :default => nil
        end
        get do
          search = ::CouponProductGroup
            .search(params[:q])
            .result
            .order("coupon_product_groups.id desc")
          groups = search.limit(params[:limit]).offset(params[:offset])
          generate_success_response( build_response_groups(groups, search.count) )
        end

        params do
        end
        get 'all' do
          generate_success_response( groups: ::CouponProductGroup.all )
        end

        params do
          requires :id, :type => Integer
        end
        get ':id' do
          group = CouponProductGroup.find_by(id: params["id"])
          generate_success_response( group: group.decorated_attributes )
        end

        params do
          requires :id, :type => Integer
        end
        delete ':id' do
          group = CouponProductGroup.find_by(id: params["id"])
          group.destroy
          generate_success_response( "ok" )
        end

        params do
          requires :id, :type => Integer
          requires :group
        end
        put ':id' do
          group = CouponProductGroup.find_by(id: params["id"])
          if group.update(params[:group])
            generate_success_response("ok")
          else
            generate_error_response( group.errors.full_messages.join(", ") )
          end
        end

        params do
          requires :group
        end
        post do
          group = CouponProductGroup.new params[:group]
          if group.save
            generate_success_response(group.decorated_attributes)
          else
            return_error_response(group.errors.full_messages.join(', '))
          end
        end

        params do
          requires :select
        end
        post ':id/add_products' do
          group = CouponProductGroup.find(params[:id])
          exist_products = group.products.where(id: params["select"]["id"])
          search_products = Product.where(id: params["select"]["id"])
          new_products = search_products - exist_products
          cc = Catalog.find_by(id: params["catalog_id"])
          if new_products.present?
            new_products.each do |pp|
              CouponProductGroupsProduct.create(coupon_product_group_id: group.id, product_id: pp.id, catalog_id: cc.id)
            end
            generate_success_response("ok")
          else
            return_error_response("error")
          end
        end

        params do
          requires :pid
        end
        post ':id/remove_products' do
          group = CouponProductGroup.find(params[:id])
          product = Product.find_by(id: params[:pid])
          if group.products.delete(product)
            generate_success_response("ok")
          else
            return_error_response("error")
          end
        end

        params do
          requires :name, :type => String
        end
        get 'find/:name' do
          group = CouponProductGroup.find_by(name: params["name"])
          generate_success_response( group: group.decorated_attributes )
        end

      end
    end
  end
end
