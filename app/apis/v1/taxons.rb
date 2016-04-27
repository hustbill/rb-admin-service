module V1
  class Taxons < ::BaseAPI
    version 'v1', using: :path
    namespace 'admin' do

      resource :taxons do

        desc 'list taxons for sortable'
        get do
          system_taxons = Taxon.system.map(&:attributes)
          parent_taxons = Taxon.parent_taxons.select{|taxon|
                            taxon.position != -1
                          }.sort_by{|x| x.position}.map{ |t|
                            t.attributes.merge(childrens: t.childrens.map(&:attributes))
                          }
          generate_success_response([system_taxons, parent_taxons])
        end

        desc 'create taxon'
        post do
          taxon = Taxon.new params[:taxon]
          taxon.taxonomy_id = 0 #for temp set
          if taxon.save
            generate_success_response(taxon.attributes)
          else
            return_error_response(taxon.errors.full_messages.join('; '))
          end
        end

        desc 'sortable'
        post 'sortable' do
          (params[:taxons_ids] || params[:child_taxons_ids]).each_with_index do |taxon_id, index|
            Taxon.where(id: taxon_id.to_i).update_all(position: index + 1)
          end
          generate_success_response('ok')
        end

        desc 'update taxon'
        put ':id' do
          taxon = Taxon.find params[:id]
          if taxon && taxon.update_attributes(params[:taxon])
            taxon.childrens.update_all(display_on: taxon.display_on) if taxon.childrens.count > 0
            if taxon.parent_id.present?
              taxon.update_column('display_on', taxon.parent.try(:display_on))
            end
            generate_success_response(taxon.attributes)
          else
            return_error_response(taxon.errors.full_messages.join('; '))
          end
        end

        desc 'show taxon childrens'
        get ':id' do
          taxon = Taxon.find params[:id]
          if taxon
            generate_success_response(
              taxon.attributes.merge({
                childrens:     taxon.childrens.map(&:attributes),
                parent_taxons: Taxon.parent_taxons.select{|taxon| taxon.position != -1}.sort_by{|x| x.name}
              })
            )
          else
            return_error_response('error')
          end
        end

      end

    end #namespace admin
  end
end