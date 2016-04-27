module V1
  class PersonalizedTypes < ::BaseAPI
    version 'v1', using: :path
    namespace 'admin' do

      resource :personalized_types do

        desc 'list all personalized types'
        get do
          generate_success_response(PersonalizedType.all.map(&:attributes))
        end

        desc 'create an personalized type'
        post do
          personalized_type = PersonalizedType.new params[:personalized_type]
          if personalized_type.save
            generate_success_response(personalized_type.attributes)
          else
            return_error_response(personalized_type.errors.full_messages.join('; '))
          end
        end

        desc 'update a catalog'
        put ':id' do
          personalized_type = PersonalizedType.find params[:id]
          if personalized_type.update_attributes params[:personalized_type]
            generate_success_response(personalized_type.attributes)
          else
            return_error_response(personalized_type.errors.full_messages.join('; '))
          end
        end

      end

    end #namespace admin
  end
end
