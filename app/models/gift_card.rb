class GiftCard < ActiveRecord::Base
  belongs_to :variant
  belongs_to :order
  validates :code, :uniqueness => true, :presence => true
  has_many :event_rewards_sources, as: :reward_source

  class << self
    def random_gift_code
      r = [('A'..'Z')].map{|i| i.to_a}.flatten - ['A', 'E','I','O','U']
      (0..12).map{ r[rand(r.length)] }.join
    end

    def random_pin
      r = [('0'..'9')].map{|i| i.to_a}.flatten
      (0..6).map{ r[rand(r.length)] }.join
    end

    def get_code
      code = random_gift_code
      while GiftCard.find_by_code(code) do
        code = random_gift_code
      end
      code
    end

    def multiple_create(entry_id, quantity, variant)
      success = 0
      failed = 0
      1.upto(quantity.to_i) do |i|
        gift = build_new_gift_card(entry_id, variant)
        if gift.save
          success += 1
        else
          failed += 1
        end
      end
      {message: "Create #{quantity} Gift Certificate, Success: #{success}, Failed: #{failed}" }
    end

    def reward_create(amount, variant_id, host_email)
      gift = GiftCard.new
      gift.variant_id = variant_id
      gift.description = "#{amount} Hostess Credits"
      gift.total = gift.balance =  amount.to_f
      gift.code = get_code
      gift.pin = random_pin
      gift.active = true
      gift.recipient_email = host_email
      gift.save
      gift
    end

    private

    def build_new_gift_card(entry_id, variant)
      gift = GiftCard.new(:entry_operator => entry_id)
      gift.variant = variant
      gift.total = gift.balance =  variant.catalog_product_variants.first.price.to_f
      gift.code = get_code
      gift.pin = random_pin
      gift.active = false
      gift
    end

  end

  def decorated_attributes
    {
      'id' => id,
      'code' => code,
      'order_id' => order_id,
      'order_number' => (order&&order.number),
      'recipient_email' => recipient_email,
      'total' => total,
      'balance' => balance,
      'pin' => pin,
      'name_to' => name_to,
      'name_from' => name_from,
      'send_email_count' => send_email_count||0,
      'email_message' => email_message,
      'active' => active,
      'description' => description,
    }
  end

end
