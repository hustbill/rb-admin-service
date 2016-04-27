class Adjustment < ActiveRecord::Base
  
  belongs_to :order
  belongs_to :source, :polymorphic => true
  belongs_to :originator, :polymorphic => true
  
   def decorated_attributes
     {
       "label" => label,
       "amount" => amount,
       "created-at" => created_at
     }
   end
  
end