class EventReward < ActiveRecord::Base
  # extends ...................................................................
  # includes ..................................................................
  # security ..................................................................
  # relationships .............................................................
  belongs_to :event_reward_type
  belongs_to :reward_source, polymorphic: true
  has_many :event_rewards_sources
  has_many :coupons, through: :event_rewards_sources, source: :reward_source, source_type: "Coupon"
  has_many :gift_cards, through: :event_rewards_sources, source: :reward_source, source_type: "GiftCard"
  # validations ...............................................................
  # callbacks .................................................................
  # scopes ....................................................................
  # additional config .........................................................
  # class methods .............................................................
  def self.create_party_rewards(event_code, variant_id, host_email)
    # create a coupon group to include all products can be discounted at 50%
    # I create one called parties_coupon
    group = CouponProductGroup.find_by(name: "Hostess Reward")

    # TODO: how to find user_id by sql
    sql = ["select sum(oo.item_total) total from events_orders eo left join orders oo on oo.number = eo.order_number where eo.event_code = ? and oo.state = ?", event_code, 'complete']
    result = ActiveRecord::Base.connection.select_one(sanitize_sql(sql))
    rank = caculate_rank(result["total"])
    return "items 0" if rank[:items].to_f <= 0
    return "Reward already created" if self.find_by(event_code: event_code) # run for once

    event_reward_type = EventRewardType.find_by(id: rank[:type_id])

    er = create(
      event_code: event_code,
      event_reward_type: event_reward_type,
      details: {event_total_order_amount: result["total"].to_f}.to_json,
      )

    if CompanyConfig::CONFIG["company_code"] == 'FTO'
      # create credit gift card
      gift_card = GiftCard.reward_create(rank[:credit], variant_id, host_email)
      EventRewardsSource.create(
        reward_source: gift_card,
        event_reward_id: er.id)
      # create percent off coupon
      create_coupon(
        group_id: group.id,
        coupon_type: "Product",
        operation: "percent_off",
        operation_amount: "50",
        total_units_allowed: rank[:items],
        event_reward_id: er.id,
        description: "Half Price Items")
    else
      # create credit coupon
      create_coupon(
        group_id: group.id,
        coupon_type: "Order",
        operation: "amount_off",
        operation_amount: rank[:credit],
        total_units_allowed: 1,
        event_reward_id: er.id,
        description: "#{rank[:credit]} Hostess Credits")

      # create percent off coupon
      create_coupon(
        group_id: group.id,
        coupon_type: "Product",
        operation: "percent_off",
        operation_amount: "50",
        total_units_allowed: rank[:items],
        event_reward_id: er.id,
        description: "Half Price Items")
    end
    return 'ok'
  end
  # public instance methods ...................................................
  def decorated_attributes
    {
      "name" => event_reward_type.name,
      "description" => event_reward_type.description,
      "coupons" => coupons.map{ |cc| cc.decorated_attributes },
      "gift_cards" => gift_cards.map{ |gg| gg.decorated_attributes },
    }
  end
  # protected instance methods ................................................
  # private instance methods ..................................................
  # private class methods

  class << self

    private

    def create_coupon(opt)
      coupon = Coupon.create(
        code: rand_code,
        description: opt[:description],
        usage_count: 1,
        coupon_type: opt[:coupon_type],
        active: true,
        is_single_user: false)
      coupon.update_rules(
        operation: opt[:operation],
        operation_amount: opt[:operation_amount],
        total_units_allowed: opt[:total_units_allowed],
        allow_all_products: false,
        coupon_product_group_id: opt[:group_id],)
      EventRewardsSource.create(
        reward_source: coupon,
        event_reward_id: opt[:event_reward_id])
    end

    def rand_code
      r = [('A'..'Z'), (0..9)].map{|i| i.to_a}.flatten - ['A', 'E','I','O','U']
      (0..12).map{ r[rand(r.length)] }.join
    end

    def caculate_rank(num)
      rank = {
        "0" => {credit: "",    items: ""},
        "1" => {credit: "15",  items: 1, type_id: 1},
        "2" => {credit: "25",  items: 2, type_id: 2},
        "3" => {credit: "45",  items: 3, type_id: 3},
        "4" => {credit: "60",  items: 4, type_id: 4},
        "5" => {credit: "90",  items: 5, type_id: 5},
        "6" => {credit: "115", items: 6, type_id: 6},
      }
      case num.to_f
      when 200...300
        rank["1"]
      when 300...400
        rank["2"]
      when 400...500
        rank["3"]
      when 500...800
        rank["4"]
      when 800...1000
        rank["5"]
      when 1000...Float::MAX
        rank["6"]
      else
        rank["0"]
      end
    end
  end
end
