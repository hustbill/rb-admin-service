class CatalogProductVariant < ActiveRecord::Base
  belongs_to :catalog_product
  belongs_to :variant
  scope :active,   -> { where('deleted_at is null') }

  def self.allowed_variant_ids(role_id)
    Catalog.autoship
  end
end
