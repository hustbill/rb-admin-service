class Role < ActiveRecord::Base
  
  has_and_belongs_to_many :users

  scope :frontend, ->{ where(is_admin: nil) }
  default_scope { order('role_code') }
  
end
