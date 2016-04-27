class Address < ActiveRecord::Base
  belongs_to :country
  belongs_to :state

  def decorated_attributes
    {
      'first-name'  => firstname,
      'm'           => middleabbr,
      'last-name'   => lastname,
      'street'      => address1,
      'street-cont' => address2,
      'city'        => city,
      'state-id'    => state_id,
      'state-name'    => (state.name rescue nil),
      'zip'         => zipcode,
      'country-id'  => country_id,
      'country-name'  => (country.name rescue nil),
      'phone'       => phone
    }
  end

  def self.generate_attributes_by_decorated_attributes(decorated_attributes)
    {
      firstname:  decorated_attributes['first-name'],
      middleabbr: decorated_attributes['m'],
      lastname:   decorated_attributes['last-name'],
      address1:   decorated_attributes['street'],
      address2:   decorated_attributes['street-cont'],
      city:       decorated_attributes['city'],
      state_id:   decorated_attributes['state-id'],
      zipcode:    decorated_attributes['zip'],
      country_id: decorated_attributes['country-id'],
      phone:      decorated_attributes['phone']
    }
  end

  def full_name
    "#{self.firstname} #{self.middleabbr} #{self.lastname}".gsub(/ {2,}|^ /," ").gsub(/^ | $/,"")
  end
end
