module ResponseHelper

  def request_info
    {
      :href           => request.url,
      :headers        => request.headers,
      :'query-params' => request.query_string,
      :body           => request.body.read
    }
  end

  def generate_success_response(response_body, code = 200)
    code = 200 if code.blank?
    status(code)
    {
      meta: { code: code },
      request: request_info,
      response: response_body
    }
  end

  def generate_error_response(error, code = 500)
    code = 500 if code.blank?
    error_data = {
      :'error-code'        => error.class.name,
      :message             => error.message,
      :data                => error.message
    }

    if Goliath.env?(:development)
      error_data['developer-message'] = error.message
      error_data[:stack] = error.backtrace
    end

    Rack::Response.new(
      [
        {
          meta: {
            code: code,
            error: error_data
          },
          request: request_info,
          response: {}
        }.to_json
      ],
      code,
      { :'Content-Type' => 'application/json' }
    )
  end

  def return_error_response(response_body, code = 500)
    code = 500 if code.blank?
    status(code)
    {
      meta: { code: code },
      request: request_info,
      response: response_body
    }
  end

end
