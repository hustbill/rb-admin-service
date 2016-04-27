module V1
  class Communities < ::BaseAPI
    version 'v1', using: :path
    namespace "admin" do
      namespace "communities" do
        desc 'create new community'
        post do
          community = Community.new params[:community]
          image = community.build_community_image
          image.attachment_file_name = params[:image]
          if community.save
            generate_success_response(community.reload.decorated_attributes)
          else
            generate_error_response(Errors::InvalidImage.new(community.errors.full_messages.join('; ')))
          end
        end

        desc 'get all'
        get do
          communities = Community.where(community_type: 'banner')
          #generate response
          generate_success_response(communities.map(&:decorated_attributes))
        end

        desc 'community detail'
        params do
          requires :id, type: Integer, desc: 'community id'
        end
        get ':id' do
          product = Community.find params[:id]
          generate_success_response(product.decorated_attributes)
        end


        desc 'update community'
        put ':id' do
          community = Community.find params[:id]
          if community
            if params[:image].present?
              community.community_image.update_attribute('attachment_file_name',params[:image])
            end

            if community.update_attributes params[:community]
              generate_success_response(community.decorated_attributes)
            else
              return_error_response(community.errors.full_messages.join('; '))
            end
          else
            return_error_response('error');
          end
        end
        
        desc 'communities wnp_banner'
        get 'wnp_banner/:type' do
          communities = Community.where(community_type: params[:type])
          #generate response
          generate_success_response(communities.map(&:decorated_attributes))
        end
        
        
        desc 'destroy community'
        delete ':id' do
          community = Community.find params[:id]
          if community.destroy
            generate_success_response("ok" )
          else
            generate_success_response("error" )
          end
        end

        desc 'community sortable'
        post 'sortable' do
          params[:community_ids].each_with_index do |community_id, index|
            Community.where(id: community_id.to_i).update_all(position: index + 1)
          end
          generate_success_response('ok')
        end
      end
    end
  end
end
