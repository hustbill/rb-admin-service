class ShippingMethod < ActiveRecord::Base

  has_one :calculator, :as => :calculable
  belongs_to :zone

  def decorated_attributes
  {
    'id' => id,
    'zone' => (zone.name rescue nil),
    'zone_description' => (zone.description rescue nil),
    'name' => name,
    'calculator' => (calculator.decorated_attributes rescue nil)
  }
  end

  def self.get_by_country_ids(country_ids)
    if country_ids.instance_of?(Array)
      select('shipping_methods.*')
      .joins('inner join zone_members on shipping_methods.zone_id = zone_members.zone_id')
      .where("zone_members.zoneable_type = 'Country'")
      .where('zone_members.zoneable_id' => country_ids.map(&:to_i))
      .where('shipping_methods.display_on is null or shipping_methods.display_on != ?', 'none')
    else
      []
    end
  end

end

