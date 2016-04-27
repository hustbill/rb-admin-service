module V1
  class Roles < ::BaseAPI
    version 'v1', using: :path
    namespace "admin" do

      resource :roles do

        desc 'list all roles.'
        get do
          generate_success_response({roles: Role.all.map(&:attributes)})
        end

        desc 'create a role'
        params do
          requires :role
        end
        post do
          role = Role.new params[:role]
          if role.save
            generate_success_response(role.attributes)
          else
            generate_success_response('error')
          end
        end

        desc 'delete a role'
        params do
          requires :id, type: Integer, desc: 'role id'
        end
        delete ':id' do
          role = Role.find(params[:id])
          if role.destroy
            generate_success_response('ok')
          else
            generate_success_response('error')
          end
        end

        desc 'show a role'
        params do
          requires :id, type: Integer, desc: 'role id'
        end
        get ':id' do
          role = Role.find(params[:id])
          generate_success_response(role.attributes)
        end

        desc 'update a catalog'
        params do
          requires :id, type: Integer, desc: 'role id'
          requires :role
        end
        put ':id' do
          role = Role.find(params[:id])
          if role.update_attributes(params[:role])
            generate_success_response(role.attributes)
          else
            generate_success_response('error')
          end
        end

      end

    end #namespace admin
  end
end