class Product < ActiveRecord::Base

  has_many :variants
  has_many :images, -> { order 'position' }, dependent: :destroy, as: :viewable
  has_one :master, -> {where('variants.is_master = ?', true)}, class_name: 'Variant'
  has_many :master_with_variants,
           ->{where('variants.deleted_at IS NULL').order('variants.is_master DESC, variants.id ASC')},
           dependent: :destroy,
           class_name: 'Variant'
  belongs_to :tax_category
  belongs_to :shipping_category
  has_and_belongs_to_many :taxons
  has_and_belongs_to_many :countries
  has_many :catalog_products, -> { where(deleted_at: nil) }
  has_many :product_option_types
  has_many :option_types, through: :product_option_types
  has_many :option_values, through: :option_types
  has_many :personalized_types_products
  has_many :active_personalized_types_products, ->{where('personalized_types_products.deleted_at is null')},
                                                class_name: 'PersonalizedTypesProduct'
  has_many :personalized_types, through: :personalized_types_products
  has_many :active_personalized_types, ->{ where('personalized_types_products.deleted_at is null') },
                                       through: :personalized_types_products,
                                       source:  :personalized_type,
                                       class_name: 'PersonalizedType'
  has_many :coupon_product_groups_products
  has_many :coupon_product_groups, through: :coupon_product_groups_products
  has_many :product_properties
  has_many :properties, through: :product_properties
  has_many :shipping_fees, -> {where(group_type: 'Calculator', owner_type: 'Product', deleted_at: nil)},
                           foreign_key: :owner_id,
                           class_name: 'Preference'
  has_many :shipping_fees_all, -> {where(group_type: 'Calculator', owner_type: 'Product')},
                               foreign_key: :owner_id,
                               class_name: 'Preference'

  has_many :product_additional_details

  before_save :replace_space

  scope :active,   -> { where('deleted_at is null') }
  scope :catalog_role_products, ->(catalog_id, role_id){
    joins(:catalog_products).where('catalog_products.catalog_id = ? and catalog_products.role_id = ?', catalog_id, role_id)
  }

  after_commit :generate_product_permalink, on: [:create, :update]
  default_scope { order('products.position') }

   def decorated_attributes
     {
       'id'          => id,
       'name'        => name,
       "description" => description,
       "created-at"  => created_at,
       "category"    => taxons.map(&:name),
       "tax"         => tax_category.try(:name).try(:titleize),
       "shipping"    => shipping_category.try(:name),
       "status"      => status
     }
   end

   def detail_attributes
     image_path = variants.first.images.first.attachment_file_name.path rescue nil
     {
       "image" => image_path
     }.merge(decorated_attributes)
   end

  def variants_images
    results = {}
    master_with_variants.each do |variant|
      images = []
      variant.images.each do |image|
        images << image.decorated_attributes.merge(
          variant_id:    variant.id,
          sku:           variant.sku,
          options_attrs: variant.option_values.map(&:name).join(',')
        )
      end
      results.update variant.sku => images
    end
    results
  end

  def master_variant_image
    master_image_path = master.images.first.attachment_file_name.small.path rescue nil
    attributes.merge master_image_path: master_image_path
  end

  def variant_price_info(catalog_product_id)
    master_with_variants.map { |v|
      v.attributes.merge(
        options:                   v.options_attrs,
        catalog_product_variant:   v.catalog_price(catalog_product_id).try(:attributes)
      )
    }
  end

  def self_images
    result = []
    images.each do |image|
      result << image.decorated_attributes.merge(
        product_id:    self.id,
        options_attrs: option_values.map(&:name).join(','),
        sku:           'All'
      )
    end
    { 'All' => result }
  end

  def all_images
    self_images.update variants_images
  end

  def status
    self.deleted_at ? 'deactive' : 'active'
  end

  def active_catalog_products
    catalog_products.where(deleted_at: nil)
  end

  def catalog_ids_to_hash
    result = {}
    active_catalog_products.each do |cp|
      if result[cp.catalog_id]
        result[cp.catalog_id] << cp.role_id
      else
        result[cp.catalog_id] = [cp.role_id]
      end
    end
    result
  end


  private

  def replace_space
    self.description = self.description.gsub("&nbsp;", " ")
  end

  def generate_product_permalink
    self.update_column('permalink', "#{self.name.gsub(/\s/, '-')}-#{self.id}") if self.name.present?
  end

end
