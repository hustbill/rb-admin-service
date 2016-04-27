CompanyConfigYml = YAML.load_file("#{Goliath.root}/config/company_config.yml").symbolize_keys

module CompanyConfig
  CONFIG = CompanyConfigYml[:config]
end
