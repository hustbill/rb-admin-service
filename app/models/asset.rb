class Asset < ActiveRecord::Base
  belongs_to :viewable, :polymorphic => true
  belongs_to :image_group
  default_scope { order('position') }
end