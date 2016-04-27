module API
  class Address < Base
    class << self
      def validate(type, params)
        unless %i(billing shipping website home).include?(type.to_sym)
          raise ArgumentError, 'type only allowed billing, shipping, website, home'
        end
        send_request(:post, params.merge(path: "/v2/addresses/#{type.to_s}/validate"))
      end
    end
  end
end
