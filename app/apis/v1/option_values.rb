module V1
  class OptionValues < ::BaseAPI
    version 'v1', using: :path
    namespace "admin" do

      resource :option_values do

        desc 'list all option values'
        get do
          #generate_success_response(OptionValue.all.map{|v| v.decorated_attributes.merge(option_type_name: v.option_type.try(:name))})
          generate_success_response(OptionType.all.map{|ot| ot.attributes.merge(option_values: ot.active_option_values.map(&:decorated_attributes))})
        end

        desc 'create a option values'
        post do
          option_type = OptionType.find(params[:option_value][:option_type_id])
          if option_type
            option_value = OptionValue.new params[:option_value]
            if params[:option_value][:presentation_type] == 'IMG'
              image = option_value.build_image
              image.attachment_file_name = params[:image]
            end
            if option_value.save
              generate_success_response({
                option_type:  option_type.attributes,
                option_value: option_value.decorated_attributes
              })
            else
              return_error_response('error')
            end
          else
            return_error_response('error')
          end
        end

        desc 'get option type values'
        get 'product_option_value' do
          option_type = OptionType.find params[:option_type_id]
          if option_type
            generate_success_response(option_type.product_option_values)
          else
            generate_error_response('error')
          end
        end

        desc 'option values sortable'
        post 'sortable' do
          params[:option_value_ids].each_with_index do |option_value_id, index|
            OptionValue.where(id: option_value_id.to_i).update_all(position: index + 1)
          end
          generate_success_response('ok')
        end

        desc 'create a option type'
        post 'create_option_type' do
          option_type = OptionType.new params[:option_type]
          if option_type.save
            generate_success_response(option_type.attributes)
          else
            return_error_response(option_type.errors.full_messages.join('; '))
          end
        end

        desc 'destroy a option value'
        delete ':id' do
          option_value = OptionValue.find params[:id]
          #option_type  = option_value.option_type
          if option_value.update_attribute('deleted_at', Time.now)
            #if option_type.option_values.count == 0
            #  option_type.destroy
            #end
            generate_success_response('ok')
          else
            generate_error_response('error')
          end
        end

        desc 'update a option value'
        put ':id' do
          option_value = OptionValue.find params[:id]
          if option_value
            if params[:image].present?
              option_value.image.update_attribute('attachment_file_name',params[:image])
              if params[:option_value] && params[:option_value][:name].present?
                option_value.update_attribute('name', params[:option_value][:name])
              else
                option_value.update_attribute('updated_at', Time.now)
              end
            elsif params[:option_value] && params[:option_value][:presentation_value].present?
              option_value.update_attributes(params[:option_value])
            end
            if option_value.errors.empty?
              generate_success_response(option_value.decorated_attributes)
            else
              return_error_response(option_value.errors.full_messages.join('; '))
            end
          else
            return_error_response('error');
          end
        end

      end

    end #namespace admin
  end
end