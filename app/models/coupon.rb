class Coupon < ActiveRecord::Base
  # extends ...................................................................
  attr_accessor :coupon_product_group_id
  alias_attribute :coupon_type, :type
  self.inheritance_column = ""
  # includes ..................................................................
  # security ..................................................................
  # relationships .............................................................
  belongs_to :coupon_product_group
  has_one :orders_coupon
  has_many :event_rewards_sources, as: :reward_source
  # validations ...............................................................
  validates_uniqueness_of :code
  # callbacks .................................................................
  # scopes ....................................................................
  # additional config .........................................................
  # class methods .............................................................
  # public instance methods ...................................................
  def decorated_attributes
    {
      "id" => id,
      "code" => code,
      "description" => description,
      "rules" => rules,
      "active" => active,
      "is_single_user" => is_single_user,
      "usage_count" => usage_count,
      "created_at" => created_at,
      "expired_at" => expired_at,
      "coupon_product_group_id" => parse_rules['coupon_product_group_id'],
      "discount" => display_discount,
      "coupon_type" => coupon_type,
      "user_id" => user_id,
      'name'    => name,
      'distributor_id' =>(self.user_id ? Distributor.find_by(user_id: self.user_id).try(:id) : nil),
      "image_url" => image_url
    }
  end

  def update_rules(input_rules)
    if input_rules[:coupon_product_group_id].present?
      input_rules[:allow_all_products] = false
    else
      input_rules[:allow_all_products] = true
      input_rules[:coupon_product_group_id] = nil
    end
    update(rules: input_rules.to_json)
  end

  def product_group
    CouponProductGroup.find(parse_rules['coupon_product_group_id']) rescue nil
  end

  def parse_rules
    JSON.parse(self.rules)
  end

  # protected instance methods ................................................
  # private instance methods ..................................................
  private

  def display_discount
    rr = JSON.parse(rules) if rules
    result = case rr["operation"]
    when "percent_off"
      "%#{rr["operation_amount"]}"
    when "amount_off"
      "$#{rr["operation_amount"]}"
    end if rr
    result
  end

end
