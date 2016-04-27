class LineItem < ActiveRecord::Base
  belongs_to :order
  belongs_to :variant
  has_one :product, :through => :variant
  has_many :line_items_personalized_values
  
  def decorated_attributes
    if CompanyConfig::CONFIG["enable_personalized_type"]
      default_attributes.merge! personalized_values
    else
      default_attributes
    end 
  end
  
  def default_attributes
    {
      "id" => variant.id,
      "sku" => variant.sku,
      "name" => variant.product.name,
      "price" => price,
      "quantity" => quantity,
      "pv" => q_volume,
      "cv" => u_volume,
      "adj_cv" => (adj_cv rescue 0.0),
      "adj_qv" => (adj_qv rescue 0.0),
      "total" => price * quantity,
      "line_item_id" => id
    }
  end
  
  def personalized_values
    personalizeds = [] 
    line_items_personalized_values.each do |v| 
      personalizeds << {personalized_name: v.personalized_name ,personalized_value: v.personalized_value}
    end
    {
      "personalized_values" => personalizeds 
    }
  end

  def self.delete_processed_id (order_id)
    sql = "delete from data_management.processed_state_events_id_for_comm_vol where processed_id in (select id from state_events where stateful_id = #{order_id})"
    ActiveRecord::Base.connection.execute(sql)
  end

end
