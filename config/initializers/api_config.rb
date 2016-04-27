APICONFIG = YAML.load_file("#{Goliath.root}/config/api_config.yml")[Goliath.env.to_s].deep_symbolize_keys
