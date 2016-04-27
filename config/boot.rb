require 'rubygems'
require 'bundler/setup'
require 'goliath'
require 'yaml'

GOLIATH_ENV = ENV['GOLIATH_ENV'] || 'development'

require 'erb'
Bundler.require(:default, Goliath.env)
module Goliath
  def self.root
    @_root ||= File.expand_path('../', __dir__)
  end
end
Dir["#{Goliath.root}/config/initializers/**/*.rb"].each { |file| require file }
ActiveSupport::Dependencies.autoload_paths += [
  "#{Goliath.root}/app/models",
  "#{Goliath.root}/app/helpers",
  "#{Goliath.root}/app/apis",
  "#{Goliath.root}/app/uploaders"
]
require "#{Goliath.root}/lib/patch"
Dir["#{Goliath.root}/lib/commissions/*.rb"].each { |file| require file }
