class Variant < ActiveRecord::Base
  belongs_to :product
  has_one :autoship_item
  has_many :variant_commissions
  has_many :inventory_units
  has_many :images, -> { order 'position' }, dependent: :destroy, as: :viewable
  has_many :product_boms
  has_many :catalog_product_variants
  has_many :gift_cards
  has_and_belongs_to_many :option_values

  validate :product_id, :sku, presence: true
  validates_uniqueness_of :sku, conditions: ->{ where('deleted_at is null') }
  validates_numericality_of :weight, :height, :width, :depth, allow_nil: true

  default_scope { order('position') }
  scope :active,   -> { where('deleted_at is null') }
  after_commit :only_one_master, on: :update
  after_commit :set_price,       on: :create

  attr_accessor :out_of_stock
  before_save   :set_count_on_hand
  
  def decorated_attributes
    {
      'sku'  => sku,
      "deleted-at" => deleted_at,
      "available-on" => available_on,
      "created-at" => created_at
    }
  end

  def status
    #return nil unless self.available_on
    #self.available_on > Time.now ? "Disactive" : "Active"
    self.deleted_at ? 'deactive' : 'active'
  end

  def combine_attrs
    attributes.merge pv:       variant_commissions.map(&:attributes),
                     sequence: self.position,
                     status:   status,
                     options_attrs: options_attrs
  end

  def catalog_price(catalog_product_id)
    catalog_product_variants.find_by catalog_product_id: catalog_product_id
  end

  def options_attrs
    result = []
    option_values.each do |ov|
      result << {ov.option_type.name => ov.name}
    end
    result
  end


private

  def only_one_master
    if self.is_master
      self.class.where(product_id: self.product_id, is_master: true)
                .where('id != ?',self.id).each do |variant|
        variant.update_column('is_master', false)
      end
    end
  end

  def set_price
    catalog_product = product.active_catalog_products.first
    if catalog_product
      cpr = catalog_product.catalog_product_variants.first
      if cpr
        product.active_catalog_products.each do |acp|
          CatalogProductVariant.new(
            catalog_product_id: acp.id,
            variant_id:         self.id,
            price:              cpr.price
          ).save
        end
      end
    end
  end

  def set_count_on_hand
    if %w{true false}.include?(out_of_stock)
      (out_of_stock == 'true') ? self.count_on_hand = -1 : self.count_on_hand = 1
    end
  end


end
