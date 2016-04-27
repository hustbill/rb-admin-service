module V1
  class ImageGroups < ::BaseAPI
    version 'v1', using: :path
    namespace 'admin' do

      resource :image_groups do

        desc 'list all image groups'
        get do
          generate_success_response(ImageGroup.all.map(&:attributes))
        end

        desc 'create a image group'
        post do
          image_group = ImageGroup.new params[:image_group]
          image_group.source_type = 'Product'
          if image_group.save
            generate_success_response(image_group.attributes)
          else
            generate_error_response('error')
          end
        end

        desc 'delete a image group'
        delete ':id' do
          image_group = ImageGroup.find params[:id]
          if image_group && image_group.destroy
            generate_success_response('ok')
          else
            generate_error_response('error')
          end
        end

        desc 'update a image group'
        put ':id' do
          image_group = ImageGroup.find params[:id]
          if image_group && image_group.update_attributes(params[:image_group])
            generate_success_response('ok')
          else
            generate_error_response('error')
          end
        end

      end

    end #namespace admin
  end
end