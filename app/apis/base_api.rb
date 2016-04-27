require "#{Goliath.root}/lib/errors"
class BaseAPI < Grape::API
  Grape::Middleware::Error.send :include, ResponseHelper
  REQUIRED_HEADERS = %w(Accept Accept-Language X-Company-Code X-User-Id)

  def self.inherited(subclass)
    super
    subclass.instance_eval do
      format :json
      helpers ResponseHelper
      helpers APIHelper

      if current_helper = "#{subclass.name.split('::').last}Helper".safe_constantize
        helpers current_helper
      end

      if current_verson_helper = "#{subclass.name}Helper".safe_constantize
        helpers current_verson_helper
      end

      before do
        if (blank_headers = REQUIRED_HEADERS.select { |key| headers[key].blank? }).present?
          raise Errors::MissingHeaders.new("required headers #{blank_headers.join(', ')}")
        end
        I18n.locale = 'en'#headers['Accept-Language']
        ActiveRecord::Base.connection_pool.connections.map(&:verify!)
      end

      after do
        ActiveRecord::Base.clear_active_connections!
      end

      rescue_from ActiveRecord::RecordNotFound do |error|
        generate_error_response(error, 404)
      end

      rescue_from Grape::Exceptions::ValidationErrors, I18n::InvalidLocale, ActiveRecord::RecordInvalid,
        Errors::TokenFailed, Errors::InvalidAutoshipItem, Errors::InvalidAutoship, Errors::InvalidAddress do |error|
        generate_error_response(error, 400)
      end

      rescue_from :all do |error|
        generate_error_response(error, 500)
      end
    end
  end
end
