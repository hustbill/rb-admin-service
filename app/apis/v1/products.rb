module V1
  class Products < ::BaseAPI
    helpers ::ProductsHelpers
    version 'v1', using: :path
    namespace "admin" do

      resource 'products' do
        desc 'list all products.'
        params do
          optional :limit, :type => Integer, :default => 25
          optional :offset, :type => Integer, :default => 0
        end
        get do
          deleted = (params[:products] == 'deleted' ? 'products.deleted_at is not null' : 'products.deleted_at is null' )
          @search = Product.where(deleted).includes(:variants).search(params[:q])
          @products = @search.result.limit(params[:limit]).offset(params[:offset]).order(order_sort_by(params[:field], params[:sort_type]))

          products = @products.map do |o|
            o.decorated_attributes.merge(:variants => o.variants.map(&:combine_attrs))
          end
          r = {
            "meta" => {
              :count => @search.result.count,
              :limit => params[:limit],
              :offset => params[:offset]
            },
            "products" => products
          }
          generate_success_response(r)
        end

        desc 'search products for coupon product group.'
        params do
        end
        get 'search' do
          sp = Catalog.find_by(code: 'SP')
          @search = Product
            .includes(:variants, :catalog_products)
            .where('products.deleted_at is null')
            .references(:variants, :catalog_products)
            .search(params[:q])
          products = @search.result.order("products.id desc")
          products_result = products.map do |pp|
            pp.decorated_attributes.merge(:variants => pp.variants.map{|vv| vv.sku }.join(","))
          end
          generate_success_response({"products" => products_result})
        end

        desc 'new product'
        get 'new' do
          month_membership = Property.find_by(name: "Months of Membership")
          months_info = {}
          if month_membership.present?
            months_info = { month_id: month_membership.id, month_value: '' }
          end
          generate_success_response(
            product_detail.merge(personalized_types: PersonalizedType.all.map(&:attributes), months_of_membership: months_info)
          )
        end

        desc 'create a product'
        post do
          product = Product.new params[:product]
          params[:catalog_ids].each_pair do |k,v|
            #"catalog_ids"=>
            #  {
            #   "1"=>{"catalog_id"=>"1", "role_ids"=>["2"]},
            #   "2"=>{"catalog_id"=>"2", "role_ids"=>["2", "6"]},
            #   "4"=>{"catalog_id"=>"4", "role_ids"=>["6"]}
            #  }
            if v['catalog_id'].to_i > 0
              v['role_ids'].each do |role_id|
                product.catalog_products << CatalogProduct.new(catalog_id: v['catalog_id'], role_id: role_id)
              end
            end
          end
          #"personalized_type"=>{"1"=>{"require"=>"true"}, "3"=>{"require"=>"true"}}
          if params[:personalized_type].present?
            params[:personalized_type].each_pair do |k, v|
              product.personalized_types_products << PersonalizedTypesProduct.new(personalized_type_id: k, required: v[:require])
            end
          end
          #build months of membership
          if (params[:months].present?)
              product.is_featured = false
              product.product_properties.build property_id: params[:months], value: params[:month_value]
          end

          #wnp product additional details
          if params[:product_additional_details].present?
            params[:product_additional_details].each_pair do |k, opts|
              product.product_additional_details << ProductAdditionalDetail.new(opts)
            end
          end

          if product.save
            create_product_shipping_fee(product, params[:shipping_handling_fee])
            generate_success_response(product.attributes)
          else
            return_error_response('error')
          end
        end

        desc 'list catalogs and roles'
        get 'catalogs_roles' do
          generate_success_response({
            catalogs: generate_hash_data(Catalog.all),
            roles:    generate_hash_data(Role.frontend)
          })
        end

        desc 'link catalog ,role , products'
        post 'catalog_products' do
          if catalog_id_role_id_exist?(params[:catalog_id], params[:role_id])
            all_products      = Product.all
            had_add_products  = Product.catalog_role_products(params[:catalog_id], params[:role_id])
            generate_success_response({
              had_add_products: had_add_products.map(&:master_variant_image),
              not_add_products: (all_products - had_add_products).map(&:master_variant_image),
              catalog:          Catalog.find(params[:catalog_id]).attributes,
              role:             Role.find(params[:role_id]).attributes
            })
          else
            generate_error_response('error')
          end
        end

        desc 'add catalog products'
        post 'add_catalog_products_disabled' do
          if catalog_id_role_id_exist?(params[:catalog_id], params[:role_id]) &&
            params[:product_ids].present? && params[:product_ids].is_a?(Array)
            params[:product_ids].each do |product_id|
              CatalogProduct.create(
                role_id:    params[:role_id],
                catalog_id: params[:catalog_id],
                product_id: product_id
              ) if Product.find(product_id)
            end
            generate_success_response('ok')
          else
            generate_error_response('error')
          end
        end

        desc 'remove catalog products'
        delete 'remove_catalog_products_disabled' do
          if catalog_id_role_id_exist?(params[:catalog_id], params[:role_id]) &&
            params[:product_id].present?

            cp = CatalogProduct.where(
              role_id:    params[:role_id],
              catalog_id: params[:catalog_id],
              product_id: params[:product_id]
            )
            if cp && cp.destroy_all
              generate_success_response('ok')
            else
              generate_error_response('error')
            end
          else
            generate_error_response('error')
          end
        end

        desc 'product group sortable'
        post 'sortable' do
          params[:product_ids].each_with_index do |product_id, index|
            Product.where(id: product_id.to_i).update_all(position: index + 1)
          end
          generate_success_response('ok')
        end

        desc 'product group'
        get 'group' do
          generate_success_response(Taxon.group_products)
        end

        desc 'variant price'
        get ':id/set_price' do
          product          = Product.find(params[:id])
          catalog_products = CatalogProduct.by_product_id(params[:id])
          if product && catalog_products.count > 0
            cp_arr = []
            catalog_products.each do |cp|
              cp_arr << {
                catalog_product_id: cp.id,
                catalog_name: cp.catalog.try(:name),
                role_name:    cp.role.try(:name),
                variants:     product.variant_price_info(cp.id)
              }
            end
            generate_success_response({
              product:          product.attributes,
              currency:         (product.countries.first.currency.attributes rescue nil),
              catalog_products: cp_arr
            })
          else
            generate_error_response('no catalog')
          end
        end

        desc 'product detail setting'
        get ':id/settings' do
          product = Product.find(params[:id])
          if product
            generate_success_response({
              product:    product.attributes,
              images:     product.all_images,
              components: product.master_with_variants.map(&:combine_attrs),
              option_types: product.option_types.map{|ot| ot.attributes.merge(option_values: ot.option_values.map(&:attributes))},
              all_option_types: generate_hash_data(OptionType.all)
            })
          else
            generate_error_response('error')
          end
        end


        desc 'product add component'
        post ':id/add_component' do
          product = Product.find(params[:id])
          if product
            params[:variant].update(is_master: true) if product.variants.count == 0
            params[:variant].update(is_master: false) if product.master
            variant = Variant.new params[:variant]
            begin
              commission_type_volume = {}
              if params[:variant_commission_types].present? && params[:variant_commission_types].instance_of?(::Hashie::Mash)
                params[:variant_commission_types].keys.each do |vct_id|
                  commission_type_volume["type#{vct_id}"] = params[:variant_commission_types][vct_id]['volume']
                  if params[:variant_commission_types][vct_id]['volume'].present?
                    variant_commission = VariantCommission.new(
                      volume:  params[:variant_commission_types][vct_id]['volume'],
                      display_on: 'all',
                      variant_commission_type_id: vct_id
                    )
                    variant.variant_commissions << variant_commission
                  end
                end
              end
              if product.variants << variant
                option_type = {}
                variant.option_values.each do |ov|
                  ot = ov.option_type
                  option_type[ot.name] = ov.name
                end
                generate_success_response(
                    variant.attributes.merge(
                        available_on: variant.available_on.try(:to_date),
                        volume: commission_type_volume,
                        out_of_stock: !(variant.count_on_hand.to_i > 0)
                    ).merge(option_type)
                )
              else
                return_error_response(variant.errors.full_messages.join('; '))
              end
            rescue => e
              puts "add component error: #{e}"
              return_error_response(variant.errors.full_messages.join('; '))
            end
          else
            return_error_response('No product')
          end
        end

        desc 'delete product option type'
        delete ':id/delete_option_type' do
          product_option_type = ProductOptionType.get_by_ids(params[:id], params[:option_type_id])
          if product_option_type.count > 0 && product_option_type.destroy_all
            generate_success_response('ok')
          else
            generate_error_response('error')
          end
        end

        desc 'product add option type'
        post ':id/add_option_type' do
          product_option_type = ProductOptionType.get_by_ids(params[:id], params[:option_type_id])
          if product_option_type.count > 0
            generate_error_response('error')
          else
            new_product_option_type = ProductOptionType.new product_id: params[:id],
                                                            option_type_id: params[:option_type_id]
            if new_product_option_type.save
              generate_success_response('ok')
            else
              generate_error_response('error')
            end
          end
        end

        desc 'create product step for new variant'
        get ':id/new_variant' do
          product      = Product.find params[:id]
          option_types = begin
                           product.option_types.map { |ot|
                             ot.attributes.merge option_values: ot.active_option_values.map(&:attributes)
                           }
                         end
          generate_success_response(
            product.attributes.merge option_types: option_types,
                                     variant_commission_types: VariantCommissionType.all.map(&:attributes)
          )
        end

        desc 'create product step for upload image'
        get ':id/new_product_image' do
          product      = Product.find params[:id]
          #option_types = begin
          #  product.option_types.map { |ot|
          #    ot.attributes.merge option_values: ot.option_values.map(&:attributes)
          #  }
          #end
          generate_success_response(
            product.attributes.merge variants: product.master_with_variants.map{|v| v.attributes.merge(options_attrs: v.options_attrs)},
                                     image_groups: ImageGroup.owner_product.map(&:attributes)
          )
        end

        desc 'add product or variant image'
        post ':id/add_product_image' do
          product = Product.find params[:id]
          if variant = params[:variant_id].present? && product.variants.find_by(id: params[:variant_id])
            image = variant.images.build
          else
            image = product.images.build
            image.image_group_id = params[:image_group_id] if params[:image_group_id].to_i > 0
          end
          image.attachment_file_name = params[:image]

          if variant && variant.save
            generate_success_response({
              variant_id: variant.id,
              image_id:   image.id,
              image_path: image.attachment_file_name.small.path,
              sku:        variant.sku
              #options_attrs: variant.option_values.map(&:name).join(',')
             })
          elsif product.save
            generate_success_response({
              product_id: product.id,
              image_id:   image.id,
              image_path: image.attachment_file_name.small.path,
              sku:        'All'
              #options_attrs: product.option_values.map(&:name).join(',')
            })
          else
            generate_error_response('error')
          end
        end

        desc 'delete a product or variant image'
        delete ':id/del_product_image' do
          product    = Product.find params[:id]
          if variant = params[:variant_id] && product.variants.find_by(id: params[:variant_id])
            image    = variant.images.find_by(id: params[:image_id])
          else
            image    = product.images.find_by(id: params[:image_id])
          end

          if image && image.destroy
            generate_success_response('ok')
          else
            generate_error_response('error')
          end
        end

        desc 'create product step for new component'
        get ':id/new_component' do
          product = Product.find params[:id]
          generate_success_response({
            product:  product.attributes,
            variants: product.master_with_variants.map(&:attributes)
          })
        end

        desc 'add component bom'
        post ':id/add_product_bom' do
          product    = Product.find params[:id]
          variant_id = params[:component].delete(:variant_id)

          if variant = variant_id && product.variants.find_by(id: variant_id)
            child_variant = Variant.find_by(sku: params[:sku])
            if child_variant
              params[:component].update variantbom_id: child_variant.id
            else
              return return_error_response('no child sku')
            end
            sfl = params[:component].delete(:shippingfeeapplicable)
            if sfl && sfl == 'yes'
              params[:component].update shippingfeeapplicable: true
            else
              params[:component].update shippingfeeapplicable: false
            end
            product_bom = ProductBom.new params[:component].update(isactive: true)
            if variant.product_boms << product_bom
              generate_success_response(
                product_bom.attributes.merge(
                  parent_sku: variant.sku,
                  child_sku:  product_bom.bom_variant.try(:sku),
                  name: (product_bom.bom_variant.product.name rescue "")
                )
              )
            else
              return_error_response('error')
            end
          else
            return_error_response('error')
          end
        end

        desc 'edit a product bom'
        get ':id/edit_product_bom' do
          product  = Product.find params[:id]
          if product
            variant_ids  = product.master_with_variants.map(&:id)
            product_boms = ProductBom.where variant_id: variant_ids
            generate_success_response(
              {
                product:      product.attributes,
                variants:     product.master_with_variants.map(&:attributes),
                product_boms: product_boms.map {|pb|
                  pb.attributes.merge(
                    name: (pb.bom_variant.product.name rescue ""),
                    parent_sku: pb.variant.try(:sku),
                    child_sku:  pb.bom_variant.try(:sku),
                    shippingfeeapplicable: (pb.shippingfeeapplicable ? 'Yes' : 'No')
                  )
                }
              }
            )
          else
            return_error_response('error')
          end
        end

        desc 'update a product bom'
        put ':id/update_product_bom' do
          product_bom = ProductBom.find params[:product_bom_id]
          if product_bom.update_attributes(params[:product_bom])
            generate_success_response('ok')
          else
            return_error_response('error')
          end
        end

        desc 'delete a component bom'
        delete ':id/del_product_bom' do
          product_bom = ProductBom.find params[:product_bom_id]
          if product_bom && product_bom.destroy
            generate_success_response('ok')
          else
            generate_error_response('error')
          end
        end

        desc 'edit product detail'
        get ':id/edit_detail' do
          product = Product.find params[:id]
          month_membership = Property.find_by(name: "Months of Membership")
          months_info = {}
          if month_membership.present?
            month_id = month_membership.id
            months_of_membership = product.product_properties.find_by(property_id: month_id)
            if months_of_membership.present?
              months_info = { month_id: month_id, month_value: months_of_membership.value }
            else
              months_info = { month_id: month_id, month_value: '' }
            end
          end
          res = product.attributes.merge({
            group:           product.taxons.map(&:id),
            option_type_ids: product.option_types.map(&:id),
            catalog_ids:     product.catalog_ids_to_hash,
            role_ids:        product.active_catalog_products.map(&:role_id).uniq,
            country_ids:     product.countries.map(&:id),
            personalized_types: PersonalizedType.all.map(&:attributes),
            active_personalized_types_products: product.active_personalized_types_products.map{|ptp| ptp.attributes.merge(name: ptp.personalized_type.try(:name))},
            months_of_membership: months_info,
            shipping_fees: product.shipping_fees.map {|sf| sf.attributes.merge(calculator: sf.calculator.try(:attributes)) }
          })

          #wnp product additional details
          if request_info[:headers]['X-Company-Code'] == 'WNP'
            res.update(product_additional_details: product.product_additional_details.map(&:attributes))
          end

          generate_success_response(product_detail.merge(res))
        end

        desc 'update product detail'
        put ':id/update_detail' do
          product = Product.find params[:id]
          params[:product].update(country_ids: []) unless params[:product][:country_ids]

          #update months of membership
          if (params[:months].present?)
            product_property = product.product_properties.find_by(property_id: params[:months])
            product.is_featured = false
            if product_property.present?
              product_property.value = params[:month_value]
              product_property.save
            else
              product.product_properties.build property_id: params[:months], value: params[:month_value]
            end
          else
            property = Property.find_by(name: 'Months of Membership')
            product_properties = property.product_properties.find_by(product_id: product.id) if property.present?
            product_properties.destroy if product_properties.present?
          end

          if product.update_attributes(params[:product])
            old_comb = []
            new_comb = []

            product.catalog_ids_to_hash.each_pair do |catalog_id, role_ids|
              #{"1"=>[2], "2"=>[2, 6], "4"=>[6]}
              role_ids.each do |role_id|
                old_comb << [catalog_id.to_i, role_id]
              end
            end

            params[:catalog_ids].each_pair do |k, v|
              #"catalog_ids"=>
              #  {
              #   "1"=>{"catalog_id"=>"1", "role_ids"=>["2"]},
              #   "2"=>{"catalog_id"=>"2", "role_ids"=>["2", "6"]},
              #   "4"=>{"catalog_id"=>"4", "role_ids"=>["6"]}
              #  }
              if v['catalog_id'].to_i > 0
                v['role_ids'].each do |role_id|
                  new_comb << [v['catalog_id'].to_i, role_id.to_i]
                end
              end
            end

            #will add
            (new_comb - old_comb).each do |comb|
              cp = product.catalog_products.where(catalog_id: comb[0], role_id: comb[1]).first
              if cp
                cp.update_column('deleted_at', nil)
                cp.catalog_product_variants.update_all(deleted_at: nil)
              else
                product.catalog_products << CatalogProduct.new(catalog_id: comb[0], role_id: comb[1])
              end
            end

            #will delete
            (old_comb - new_comb).each do |comb|
              cp = product.catalog_products.where(catalog_id: comb[0], role_id: comb[1]).first
              if cp
                cp.update_column('deleted_at', Time.now)
                cp.catalog_product_variants.update_all(deleted_at: Time.now)
              end
            end

            update_personalized_types(product, params[:personalized_type])
            update_product_shipping_fee(product, params[:shipping_handling_fee])
            update_wnp_product_additional_details(product, params[:product_additional_details]) if request_info[:headers]['X-Company-Code'] == 'WNP'
            generate_success_response({added: (new_comb - old_comb).present?})
          else
            return_error_response('error')
          end
        end

        desc 'edit product variant'
        get ':id/edit_variant' do
          product      = Product.find params[:id]
          option_types = begin
            product.option_types.map { |ot|
              ot.attributes.merge option_values: ot.active_option_values.map(&:attributes)
            }
          end
          generate_success_response(
            product.attributes.merge(
              option_types: option_types,
              variants: product.master_with_variants.map(&:combine_attrs),
              variant_commission_types: VariantCommissionType.all.map(&:attributes)
            )
          )
        end

        desc 'edit product images'
        get ':id/edit_product_image' do
          product = Product.find params[:id]
          generate_success_response(
            product.attributes.merge variants: product.master_with_variants.map{|v| v.attributes.merge(options_attrs: v.options_attrs)},
                                     images:   product.all_images,
                                     image_groups: ImageGroup.owner_product.map(&:attributes)
          )
        end


	desc 'edit product'
        get ':id/edit' do
          res = {
            catalogs:            generate_hash_data(Catalog.all),
            tax_categories:      generate_hash_data(TaxCategory.all),
            shipping_categories: generate_hash_data(ShippingCategory.all),
            countries: Country.all_clientactive.inject([]){|r, i| r.push({id: i.id,name: i.name})}
          }
          generate_success_response(res)
        end

        desc 'update product'
        put ':id' do
          product = Product.find params[:id]
          if params[:product].delete(:status) == 'deactive'
            params[:product].update deleted_at: Time.now
          else
            params[:product].update deleted_at: nil
          end
          if product.update_attributes params[:product]
            generate_success_response("ok" )
          else
            generate_success_response("error" )
          end
        end

        desc 'destroy product'
        delete ':id' do
          product = Product.find params[:id]
          if product.destroy
            generate_success_response("ok" )
          else
            generate_success_response("error" )
          end
        end

        desc 'product detail'
        params do
          requires :id, type: Integer, desc: 'product id'
        end
        get ':id' do
          product = Product.find params[:id]
          # open('/tmp/1.png')
          generate_success_response(product.detail_attributes )
        end

        desc 'update product image'
        params do
          requires :image#, :type => Rack::Multipart::UploadedFile, :desc => "Image file."
        end
        patch ':id/image' do
          # new_file = ActionDispatch::Http::UploadedFile.new(params[:image])
          product = Product.find params[:id]
          variant = product.variants.first
          variant.images.destroy_all
          # puts params[:image]
          # puts "*"* 20
          # puts = Base64.decode64(params[:image])
          image   = variant.images.build
          image.attachment_file_name = params[:image]
          if variant.save
            generate_success_response("ok" )
          else
            generate_error_response(Errors::InvalidImage.new(variant.errors.full_messages.join('; ')))
          end
        end

        desc 'update product description'
        params do
          requires :description
        end
        put ':id/update_description' do
          product = Product.find params[:id]
          if product.update_attribute(:description, params[:description])
            generate_success_response("ok" )
          else
            generate_success_response("error" )
          end
        end

        desc 'get currency'
        params do
          requires :id
        end
        get ':id/get_currency' do
          product = Product.find params[:id]
          r = {
            "code" => product.countries.first.currency.iso_code,
            "symbol" => product.countries.first.currency.symbol
          }
          generate_success_response(r)
        end


        desc 'update product renewal month'
        put ':id/update_renewal_month' do
          product = Product.find params[:id].to_i
          if product && params[:property_id].to_i > 0 && params[:month_value].to_i > 0
            product.taxon_ids = params[:product_group]
            product.is_featured = false
            product_property = product.product_properties.find_by(property_id: params[:property_id].to_i)
            if product_property.blank?
              product_property = product.product_properties.build property_id: params[:property_id].to_i, value: params[:month_value]
            else
              product_property.value = params[:month_value]
              product_property.save
            end
            if product.save
              generate_success_response('ok')
            else
              return_error_response('error')
            end
          else
            return_error_response('error')
          end
        end

        desc 'delete product additional details'
        delete ':product_id/del_product_additional_detail' do
          product = Product.find params[:product_id].to_i
          if product
            product_additional_detail = product.product_additional_details.where(id: params[:id].to_i).first
            if product_additional_detail && product_additional_detail.destroy
              generate_success_response('ok')
            else
              return_error_response('error')
            end
          else
            return_error_response('error')
          end
        end

        desc 'product editor upload description image'
        params do
          requires :image#, :type => Rack::Multipart::UploadedFile, :desc => "Image file."
        end
        post 'upload_description_image' do
          image   = ProductDescription.new
          image.attachment_file_name = params[:image]
          if image.save
            generate_success_response(image.reload.decorated_attributes)
          else
            generate_error_response(Errors::InvalidImage.new(variant.errors.full_messages.join('; ')))
          end
        end


      end
    end
  end
end
