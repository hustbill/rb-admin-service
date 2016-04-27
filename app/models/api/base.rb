module API
  class Base
    class HTTPMethodError < StandardError; end
    class RequestError    < StandardError; end

    HEADER_WHITE_LIST = %w(Host Content-Length Accept Accept-Language Content-Type X-Authentication-Token User-Agent X-Device-UUID X-Device-Info X-WSSID-Authorization X-Client-Id X-Client-Secret X-User-Id X-Company-Code)
    DEFAULT_HEADERS = {
      content_type: 'application/json',
      accept: 'application/json',
      accept_language: 'en-US',
      x_client_id: APICONFIG[:x_client_id],
      x_client_secret: APICONFIG[:x_client_secret]
    }

    class << self
      def send_request(http_method, params)
        RestClient.send(*generate_restclient_arguments(http_method, params)) do |response, request, result|
          API::Response.new response
        end
      end

      private

      def generate_restclient_arguments(http_method, params)
        params.symbolize_keys!
        path     = params.delete(:path)
        base_url = params.delete(:base_url) || APICONFIG[:base_url]
        headers = {}

        HEADER_WHITE_LIST.each do |key|
          headers[key.to_sym] = params.delete(key.to_sym) if params[key.to_sym].present?
        end

        case http_method.to_sym
        when :get, :head, :delete, :options
          [http_method.to_sym, "#{base_url}#{path}", DEFAULT_HEADERS.merge(headers).merge(params: params)]
        when :put, :post, :patch
          [http_method.to_sym, "#{base_url}#{path}", params.to_json, DEFAULT_HEADERS.merge(headers)]
        else
          raise HTTPMethodError, "#{http_method.to_s} invalid, http method only allowed get, head, delete, options, put, post, patch"
        end
      end
    end
  end
end

