class CatalogProduct < ActiveRecord::Base
  has_many :catalog_product_variants, -> { where('deleted_at is null') }
  belongs_to :role
  belongs_to :catalog
  belongs_to :product

  scope :active,   -> { where('deleted_at is null') }
  scope :by_product_id, ->(product_id) { where(product_id: product_id, deleted_at: nil) }

  def decorated_attributes
    cpv = []
    catalog_product_variants.each do |e|
      if e.deleted_at.nil? && e.variant.present?
        cpv << {:id=>e.variant.id, :sku=>e.variant.sku}
      end
    end
    if deleted_at.nil?
      {:id=>product.id, :name=>product.name, :role=>role.name, :variants => cpv}
    else
      nil
    end
  end

end
