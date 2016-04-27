module V1
  class Catalogs < ::BaseAPI
    version 'v1', using: :path
    namespace "admin" do

      resource :catalogs do

        desc 'list all catalogs.'
        get do
          products = Product.active
          variants = Variant.active
          catalogs = Catalog.active.map(&:attributes)
          roles    = Role.frontend
          #catalogproducts = CatalogProduct.search(params[:q]).result.map{|i| (i[:deleted_at]==nil)? i:{}}.compact
          catalogproducts = CatalogProduct.joins(:product).where('catalog_products.deleted_at is null and products.deleted_at is null').search(params[:q]).result

          #preparations for combinations
          rs1 = roles.map{|r| {r[:id]=>r[:name]}}.reduce(:merge)
          ps2 = products.map{|p| {p[:id]=>p[:name]}}.reduce(:merge)
          vs3 = variants.map{|v| {v[:id]=>v[:sku]}}.reduce(:merge)

          #combine product and catalog_product
          cps4 = catalogproducts.map{|cp| {:catalog_product_id=>cp[:id], :role_id=>cp[:role_id], :catalog_id=>cp[:catalog_id], :product_id=>cp[:product_id]}}
          cpsp5 = cps4.map{|cp| {:name=>ps2[cp[:product_id]]}.merge(cp)}.map{|cp| {:role=>rs1[cp[:role_id]]}.merge(cp)}

          #combine variant and catalog_product_variant
          #cpvs6 = CatalogProductVariant.active.map{|cpv| {:variant_id=>cpv[:variant_id], :catalog_product_id=>cpv[:catalog_product_id]}}
          cpvs6 = CatalogProductVariant.joins(:variant).where('catalog_product_variants.deleted_at is null and variants.deleted_at is null').map{|cpv| {:variant_id=>cpv[:variant_id], :catalog_product_id=>cpv[:catalog_product_id]}}
          cpvsv7 = cpvs6.map{|cpv| {:sku=>vs3[cpv[:variant_id]]}.merge(cpv)}

          #combine catalog_product and catalog_product_variant
          cpvsg8 = cpvsv7.group_by{|cpv| cpv[:catalog_product_id]}
          cpsv9 = cpsp5.map{|cp| {:variants=>cpvsg8[cp[:catalog_product_id]]}.merge(cp)}

          #combine catalog and catalog_product
          cpsvg0 = cpsv9.group_by{|cpwv| cpwv[:catalog_id]}
          cata = catalogs.map{|c| {:products=>cpsvg0[c['id']]}.merge(c)}

          #generate response
          generate_success_response({
            catalogs: cata,
            roles:    roles.map(&:attributes),
            products: products.map{|p| {:id=>p[:id], :name=>p[:name]}},
            variants: variants.map{|v| {:id=>v[:id], :sku=>v[:sku]}}
          })
        end

        desc "get all catalogs list"
        get "all" do
          generate_success_response( catalogs: ::Catalog.all )
        end

        desc 'create a catalog'
        #params do
        #  requires :name
        #end
        post do
          if Catalog.find_by(code: params[:catalog][:code])
            return_error_response('the catalog code had exists')
          else
            roles            = Role.frontend
            catalog_role_ids = params[:catalog].delete(:catalog_role_ids)
            catalog = Catalog.new params[:catalog]

            if catalog_role_ids
              if catalog_role_ids.length == 1
                catalog.roleships << Roleship.new(source_role_id: catalog_role_ids.first, destination_role_id: catalog_role_ids.first)
              elsif catalog_role_ids.length == 2
                d_code = roles.select {|r| r.role_code == 'D'}.first
                r_code = roles.select {|r| r.role_code == 'R'}.first
                [ [d_code, d_code], [r_code, r_code], [d_code, r_code] ].each do |rc|
                  catalog.roleships << Roleship.new(source_role_id: rc[0].id, destination_role_id: rc[1].id)
                end
              end
            end

            if catalog.save
              generate_success_response(catalog.decorated_attributes)
            else
              return_error_response("failed")
            end
          end
        end

        desc 'delete a catalog'
        params do
          requires :id, type: Integer, desc: 'catalog id'
        end
        delete ':id' do
          catalog = Catalog.find(params[:id])
          if catalog && catalog.update_attribute('deleted_at', Time.now)
            generate_success_response('success')
          else
            generate_success_response('failed')
          end
        end

        desc 'show a catalog'
        params do
          requires :id, type: Integer, desc: 'catalog id'
        end
        get ':id' do
          catalog = Catalog.find(params[:id])
          generate_success_response(catalog.decorated_attributes)
        end

        desc 'update a catalog'
        params do
          requires :id, type: Integer, desc: 'catalog id'
          requires :catalog
        end
        put ':id' do
          catalog_by_code = Catalog.find_by(code: params[:catalog][:code])
          catalog = Catalog.find(params[:id])
          if catalog_by_code && catalog_by_code != catalog
            generate_success_response("failed")
          else
            roles            = Role.frontend
            catalog_role_ids = params[:catalog].delete(:catalog_role_ids)
            if catalog.update_attributes(params[:catalog])
              if catalog_role_ids
                if catalog_role_ids.length == 1
                  unless catalog.roleships.where(source_role_id: catalog_role_ids.first, destination_role_id: catalog_role_ids.first).first
                    catalog.roleships << Roleship.new(source_role_id: catalog_role_ids.first, destination_role_id: catalog_role_ids.first)
                  end
                elsif catalog_role_ids.length == 2
                  d_code = roles.select {|r| r.role_code == 'D'}.first
                  r_code = roles.select {|r| r.role_code == 'R'}.first

                  [ [d_code, d_code], [r_code, r_code], [d_code, r_code] ].each do |rc|
                    unless catalog.roleships.where(source_role_id: rc[0].id, destination_role_id: rc[1].id).first
                      catalog.roleships << Roleship.new(source_role_id: rc[0].id, destination_role_id: rc[1].id)
                    end
                  end
                end
              end
              generate_success_response(catalog.decorated_attributes)
            else
              generate_success_response("failed")
            end
          end
        end

        desc 'delete a catalog product'
        params do
          requires :id, type: Integer
        end
        delete 'product/:id' do
          catalog_product = CatalogProduct.find(params[:id])
          if catalog_product && catalog_product.update_attribute('deleted_at', Time.now)
            generate_success_response('success')
          else
            generate_error_response('failed')
          end
        end

        desc 'add a catalog product'
        params do
          requires :role_id, type: Integer
          requires :product_id, type: Integer
          requires :catalog_id, type: Integer
        end
        post 'product' do
          catalog_product = CatalogProduct.find_by(role_id: params['role_id'], product_id: params['product_id'], catalog_id: params['catalog_id'])
          if catalog_product
            if catalog_product['deleted_at'] && catalog_product.update_attribute('deleted_at', nil)
              generate_success_response('success')
            else
              generate_error_response('failed')
            end
          else
            cata = CatalogProduct.new(role_id: params['role_id'], product_id: params['product_id'], catalog_id: params['catalog_id'])
            if cata.save
              generate_success_response('success')
            else
              generate_error_response('failed')
            end
          end
        end

      end

    end #namespace admin
  end
end
