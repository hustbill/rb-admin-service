class Zone < ActiveRecord::Base
  has_one    :legal_entity
  has_many   :zone_members, :dependent => :destroy

  def include?(address)
    return false unless address

    country_id = (address.country_id.blank? ? 0 : address.country_id)
    state_id   = (address.state_id.blank? ? 0 : address.state_id)

    sql = "select * from is_address_in_zone(#{self.id},#{country_id}, #{state_id})"
    result = ActiveRecord::Base.connection.select_all(sql)
    return true if result[0]['is_address_in_zone'] == 't'
    return false
  end

  def all_members_list
    members.map {|zone_member|
      case zone_member.zoneable_type
      when "Zone"
        zone_member.zoneable.all_members_list
      when "Country"
        zone_member.zoneable
      when "State"
        zone_member.zoneable
      else
        nil
      end
    }.flatten.compact.uniq
  end

  def include_zone?(zone)
    zone_members_1 = self.all_members_list
    zone_members_2 = zone.all_members_list
    (zone_members_1 & zone_members_2) == zone_members_2
  end
end