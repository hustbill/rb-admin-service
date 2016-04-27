module API
  class Payment < Base
    class << self
      def create_token(params)
        send_request(:post, params.merge(path: '/v1/tokens', 'X-Client-Id' => APICONFIG[:payment][:x_client_id], base_url: APICONFIG[:payment][:base_url]))
      end
    end
  end
end
