module V1
  class Variants < ::BaseAPI
    version 'v1', using: :path
    namespace "admin" do

      resource :variants do

        desc 'return variant data info'
        params do
          requires :product_id
          requires :variant_id
        end
        get 'setting' do
          product = Product.find params[:product_id]
          variant = product.variants.find_by(id: params[:variant_id])
          if variant
            generate_success_response({
              variant: variant.attributes,
              images:  variant.images.map(&:decorated_attributes)
            })
          else
            generate_error_response('error')
          end
        end

        desc 'variant sortable'
        post 'sortable' do
          params[:variant_position].each_with_index do |variant_id, index|
            Variant.where(id: variant_id.to_i).update_all(position: index + 1)
          end
          generate_success_response('ok')
        end

        desc 'check sku exist'
        params do
          requires :sku
        end
        get 'check_sku_exists' do
          variants = Variant.active.where(sku: params[:sku])
          if variants.length > 0
            generate_success_response('exist')
          else
            generate_success_response('not exist')
          end
        end

        desc 'upload image'
        params do
          requires :image
        end
        post ':id/upload_image' do
          variant = Variant.find params[:id]
          image   = variant.images.build
          image.attachment_file_name = params[:image]

          if variant.save
            generate_success_response({
              variant_id: variant.id,
              image_id:   image.id,
              image_path: image.attachment_file_name.small.path
            })
          else
            generate_error_response(Errors::InvalidImage.new(variant.errors.full_messages.join('; ')))
          end
        end

        desc 'delete image'
        params do
          requires :image_id
        end
        delete ':id/delete_image' do
          variant = Variant.find params[:id]
          image   = variant.images.find_by(id: params[:image_id])
          if image && image.destroy
            generate_success_response('ok')
          else
            generate_error_response('error')
          end
        end

        desc 'update'
        put ':id/update' do
          begin
            variant = Variant.find(params[:id])
            if params[:variant][:is_master] == 'Yes'
              params[:variant][:is_master] = true
            else
              params[:variant][:is_master] = false
            end
            if variant.update_attributes(params[:variant].to_h)
              if params[:variant_commission_types].present? &&
                   params[:variant_commission_types].instance_of?(::Hashie::Mash)

                params[:variant_commission_types].keys.each do |vct_id|
                  volume = params[:variant_commission_types][vct_id]['volume']
                  if volume.present?
                    vc = variant.variant_commissions.find_by(variant_commission_type_id: vct_id)
                    if vc
                      vc.update_attribute 'volume', volume
                    else
                      variant_commission = VariantCommission.new(
                        volume:  volume,
                        display_on: 'all',
                        variant_commission_type_id: vct_id
                      )
                      variant.variant_commissions << variant_commission
                    end
                  end
                end
              end
              generate_success_response('ok')
            else
              return_error_response('error')
            end
          rescue => e
            return_error_response(e)
          end
        end

        desc 'destroy'
        delete ':id/destroy' do
          product = Product.find(params[:product_id])
          variant = product.variants.find_by(id: params[:id])
          if variant && variant.update_attribute('deleted_at', Time.now)
            generate_success_response('ok')
          else
            generate_error_response('error')
          end
        end

        desc 'update a variant price'
        put ':id/update_price' do
          catalog_product_variant = CatalogProductVariant.find params[:catalog_product_variant_id]
          if catalog_product_variant && catalog_product_variant.update_attribute('price', params[:price])
            generate_success_response('ok')
          else
            generate_error_response('error')
          end
        end

        desc 'create a variant price'
        post ':id/create_price' do
          variant = Variant.find params[:id]
          c_p_v = variant.catalog_price(params[:catalog_product_id])
          if c_p_v && c_p_v.update_attribute('price', params[:price])
            generate_success_response('ok')
          else
            catalog_product         = CatalogProduct.find params[:catalog_product_id]
            catalog_product_variant = CatalogProductVariant.new variant_id: params[:id], price: params[:price]
            if catalog_product && catalog_product.catalog_product_variants << catalog_product_variant
              generate_success_response('ok')
            else
              generate_error_response('error')
            end
          end
        end

        desc 'set price for all variants'
        post 'set_price_all' do
          catalog_product         = CatalogProduct.find params[:catalog_product_id]
          product                 = Product.find catalog_product.product_id
          variants                = product.variants

          variants.each do |v|
            if v.deleted_at
              next
            end
            cpv = v.catalog_price(params[:catalog_product_id])
            if cpv #update
              cpv.update_attribute('price', params[:price])
            else #create
              c_p_v = CatalogProductVariant.new variant_id: v[:id], price: params[:price]
              if c_p_v
                catalog_product.catalog_product_variants << c_p_v
              end
            end
          end # of each do
          generate_success_response('ok')
        end

        desc 'update amount'
        params do
          requires :id, :type => Integer
          requires :new, :type => Integer
          requires :load, :type => Integer
        end
        put ':id/update_amount' do
          begin
            Report.update_amount(params)
            generate_success_response('ok')
          rescue => e
            return_error_response(e)
          end
        end

        desc 'update variant state'
        put ':id/update_state' do
          variant = Variant.find(params[:id])
          if variant && params[:variant].present?
            deleted_at = (params[:variant][:status] == 'deactive') ? Time.now : nil
            if variant.update_attribute('deleted_at', deleted_at)
              generate_success_response('ok')
            else
              return_error_response('error')
            end
          else
            return_error_response('error')
          end
        end

      end #resource :variants

    end #namespace admin
  end
end
