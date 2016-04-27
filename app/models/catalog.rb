class Catalog < ActiveRecord::Base
  has_many :catalog_products, -> { where('deleted_at is null') }

  validate :name, :code, presence: true
  validates_uniqueness_of :code

  scope :autoship, -> { find_by!(name: 'Autoship') }
  scope :active,   -> { where('deleted_at is null') }

  has_many :roles, ->{ uniq }, through: :catalog_products, source: :role
  has_many :catalog_products
  has_many :roleships
  has_many :catalog_roles, ->{ uniq }, through: :roleships, source: :role

  def decorated_attributes
    attributes.merge catalog_roles: catalog_roles.map(&:attributes)
  end

end
