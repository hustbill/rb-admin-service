class Payment < ActiveRecord::Base
  
  belongs_to :payment_method
  belongs_to :order

  scope :completed, -> { where(state: 'completed') }
  
  def decorated_attributes
    {
      "id" => id,
      "payment-method-id" => payment_method_id,
      "payment-method-name" => payment_method.name,
      "payment-method-type" => payment_method.type,
      "amount" => amount,
      "state" => state,
      "payment-date" => created_at
    }
  end
  
  def capture
    self.update_attribute(:state, "completed")
    self.order.push_order
  end
  
end



#                                          Table "public.payments"
#       Column        |            Type             |                       Modifiers                       
#---------------------+-----------------------------+-------------------------------------------------------
# id                  | integer                     | not null default nextval('payments_id_seq'::regclass)
# order_id            | bigint                      | 
# amount              | numeric(12,2)               | not null default 0.0
# source_id           | integer                     | 
# source_type         | character varying(255)      | 
# payment_method_id   | integer                     | 
# state               | character varying(255)      | 
# response_code       | character varying(255)      | 
# avs_response        | character varying(255)      | 
# autoship_payment_id | integer                     | 
# bill_address_id     | integer                     | 
# created_at          | timestamp without time zone | 
# updated_at          | timestamp without time zone | 