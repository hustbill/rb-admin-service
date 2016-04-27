class Order < ActiveRecord::Base

  belongs_to :user
  belongs_to :entry_user, :class_name => "User", :foreign_key => "entry_operator"
  belongs_to :bill_address, :foreign_key => "bill_address_id", :class_name => "Address"
  belongs_to :ship_address, :foreign_key => "ship_address_id", :class_name => "Address"
  has_many :line_items, :dependent => :destroy
  belongs_to :currency
  belongs_to :shipping_method
  has_many :payments
  has_many :shipments
  has_many :adjustments
  has_many :state_events, :as => :stateful
  has_many :inventory_units
  has_many :state_events, as: :stateful
  has_many :orders_coupons
  has_many :admin_notes, as: :source, dependent: :destroy
  scope :by_shipment_state, ->(state) { where(shipment_state: state) if state.present? }
  scope :by_payment_state,  ->(state) { where(payment_state: state) if state.present? }
  scope :by_order_state,    ->(state) { where(state: state) if state.present? }
  scope :by_order_date,     ->(date) { where("DATE(order_date) = ?", date) if date.present? }
  scope :by_number,         ->(number) { where("number like ?", "%#{number}%") if number.present? }

  has_one :orders_sponsor

  def decorated_attributes
    {
      'number'  => number,
      "id" => id,
      "user-id" => user_id,
      "distributor-id" => user.distributor.id,
      "login"          => user.try(:login),
      'order-date'  => order_date,
      'item-total'  => item_total,
      'adjustment-total'  => adjustment_total,
      'total'  => total,
      'shipment-state'  => shipment_state,
      'payment-state'  => payment_state,
      'payment-total'  => payment_total,
      'state'  => state,
      'order_type_id'  => order_type_id,
      "shipping-method-id" => shipping_method_id,
      "shipping-method-name" => shipping_method.try(:name),
      "special-instructions" => special_instructions,
      "completed-at" => completed_at
    }
  end

  def legal_entity
    les = LegalEntity.all.map {|e| e if e.zone.present? && e.zone.include?(self.ship_address)}.compact
    if les.size == 0
      LegalEntity.new
    elsif les.size == 2 && les[0].zone.present? && les[1].zone.present? && les[0].zone.include_zone?(les[1].zone)
      les[1]
    else
      les.first
    end
  end

  def push_order
    self.update_attributes(payment_state: 'paid', shipment_state: 'ready', completed_at: Time.now.utc)
    self.shipments.first.update_attribute(:state, 'ready')
    e = self.state_events.build
    e.user_id = user_id
    e.name = 'payment'
    e.previous_state = 'balance_due'
    e.next_state = 'paid'
    e.save
    line_items.each do |item|
      1.upto(item.quantity) do
        i = self.inventory_units.build
        i.variant_id = item.variant_id
        i.state = 'sold'
        i.lock_version = 0
        i.shipment = shipments.first
        i.save
      end
    end
  end

  def payment_method_name
    if self.payment_state == "failed"
      get_payment_method("failed").name rescue nil
    else
      get_payment_method("complete").name rescue nil
    end
  end

  #@param[string] failed or complete
  def get_payment_method(payment_state)
    payments.select{|payment| payment.state == payment_state}.first.payment_methods
  end

  scope :by_payment_method, ->(method_name) {
    case method_name
    when 'cash_check'
      db_method_name = 'Cash/Check'
    when 'credit_card'
      db_method_name = 'Creditcard' # zoivi is `Credit Card`, miion is `Creditcard`
    end
    select("orders.*, payments.order_id, payments.payment_method_id, payment_methods.id, payment_methods.name").
    joins("left join payments on payments.order_id = orders.id").
    joins("left join payment_methods on payments.payment_method_id = payment_methods.id").
    where("payment_methods.name = ?", db_method_name) if method_name.present? }

  scope :by_sku, ->(sku) {
    joins("left join line_items on line_items.order_id = orders.id").
    joins("left join variants on variants.id = line_items.variant_id").
    where("variants.sku = ?", sku) if sku.present? }

  scope :by_product_name, ->(product_name) {
    joins("left join line_items on line_items.order_id = orders.id").
    joins("left join variants on variants.id = line_items.variant_id").
    joins("left join products on products.id = variants.product_id").
    where("products.name = ?", product_name) if product_name.present? }

  def force_date(date)
    order_date = created_at.strftime("%Y-%m-%d")
    function_name = ( date > order_date ? "set_forward_order_date" : "set_back_order_date" )
    result = ActiveRecord::Base.connection.select_one("select #{function_name}(#{id}, '#{date.gsub(/-/,"")}', true)")
    [number,''] if result.class == Hash && result[function_name] == "0"
  rescue => e
    logger.error e.to_s
    case e.to_s
    when /Please try in one hour.$/
      return ["","#{number}"]
    else
      return ["",""]
    end
  end

end


=begin
"user_id": 15589,
     "number": "Z00000001043",
     "order_date": "2013-07-20T08:46:00Z",
     "item_total": "1170.0",
     "total": "1170.0",
     "state": "completed",
     "adjustment_total": "0.0",
     "credit_total": "0.0",
     "completed_at": null,
     "bill_address_id": null,
     "ship_address_id": null,
     "payment_total": "0.0",
     "shipping_method_id": null,
     "shipment_state": null,
     "payment_state": null,
     "email": null,
     "special_instructions": null,
     "distributor": true,
     "autoship": null,
     "balance": null,
     "entry_operator": null,
     "order_entry_date": null,
     "currency_id": null,
     "order_type_id": null,
     "autoship_id": null,
     "created_at": "2014-02-23T08:54:27Z",
     "updated_at": "2014-02-23T08:54:27Z",
     "avatax_commit": false,
     "avatax_get": false,
     "avatax_post": false,
     "role_id": null
=end
