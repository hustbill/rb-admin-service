class PaymentMethod < ActiveRecord::Base
  
  self.inheritance_column = :foo
  
end