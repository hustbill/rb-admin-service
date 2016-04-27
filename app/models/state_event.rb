class StateEvent < ActiveRecord::Base
  belongs_to :order, polymorphic: true  
end