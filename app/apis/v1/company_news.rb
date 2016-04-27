module V1
  class CompanyNews < ::BaseAPI
    version 'v1', using: :path
    namespace "admin" do
      namespace "company_news" do
        desc 'company news editor upload description image'
        params do
          requires :image
        end
        post 'upload_description_image' do
          image = CompanyNewsDescription.new
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