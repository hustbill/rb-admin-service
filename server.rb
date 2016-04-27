require "#{__dir__}/config/boot"
class Application < Goliath::API
  use Rack::Config do |env|
    env['rack.url_scheme'] ||= 'http'
    env['SCRIPT_NAME'] = nil
  end

  def response(env)
    ::Admin.call(env)
  end
end
