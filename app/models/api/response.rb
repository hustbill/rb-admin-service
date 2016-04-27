module API
  class Response
    attr_accessor :response

    def initialize(response)
      @response = response
    end

    def success?
      response.code == 200
    end

    def request
      response_body['request']
    end

    def meta
      response_body['meta']
    end

    def body
      response_body['response']
    end

    def error_message
      meta && meta["error"] && meta["error"]["message"]
    end

    private

    def response_body
      return @response_body if defined?(@response_body)
      @response_body = JSON.parse(response.body)
    end
  end
end
