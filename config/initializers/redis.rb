require 'redis'
require 'redis/connection/hiredis'

$redis = Redis.new(YAML.load_file("#{Goliath.root}/config/redis.yml").symbolize_keys[:cache])
I18n.enforce_available_locales = true