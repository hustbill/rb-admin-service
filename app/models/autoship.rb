class Autoship < ActiveRecord::Base
  has_many :autoship_items, :dependent => :destroy
  has_many :autoship_payments, :dependent => :destroy
  belongs_to :ship_address, :class_name => 'Address'
  belongs_to :bill_address, :class_name => 'Address'
  belongs_to :user

  has_many :orders

  validates :active_date, :start_date, :shipping_method_id, :state, :presence => true

  accepts_nested_attributes_for :autoship_items, :allow_destroy => true, :reject_if => proc { |attributes| attributes['quantity'].blank? || attributes['quantity'].to_i == 0 }
  accepts_nested_attributes_for :ship_address, :allow_destroy => true
  accepts_nested_attributes_for :bill_address, :allow_destroy => true
  accepts_nested_attributes_for :autoship_payments, :allow_destroy => true

  def active?
    state == 'active'
  end

  def variants_price_hash
    variant_ids = self.autoship_items.map(&:variant_id)
    autoship_catalog = Catalog.autoship
    CatalogProductVariant.select('catalog_product_variants.*').where(variant_id: variant_ids, catalog_products: { role_id: self.role_id, catalog_id: autoship_catalog.id }).joins(:catalog_product).inject({}) do |h, catalog_product_variant|
      h[catalog_product_variant.variant_id] = catalog_product_variant.price; h
    end
  end

  def not_allowed_variant_ids
    if (variant_ids = self.autoship_items.map(&:variant_id)).blank?
      return []
    end
    autoship_catalog = Catalog.autoship
    allowed_variant_ids = CatalogProductVariant.where(variant_id: variant_ids, catalog_products: { role_id: self.role_id, catalog_id: autoship_catalog.id }).joins(:catalog_product).pluck(:variant_id)
    variant_ids - allowed_variant_ids
  end
end
