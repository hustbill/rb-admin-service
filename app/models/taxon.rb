class Taxon < ActiveRecord::Base
  has_and_belongs_to_many :products
  scope :front, ->{ where('position > 0') }
  scope :has_child_taxon_ids, -> { select('parent_id').where('parent_id > 0').group('parent_id') }
  scope :parent_taxons,       -> { where(parent_id: nil).order('name') }
  scope :system, ->{ where('position = -1') }

  validate :name, presence: true
  validates_uniqueness_of :name

  default_scope { order('position') }
  after_commit :set_taxonomy_id, on: :create
  after_commit :set_display_on, on: :create

  def self.has_childs
    parent_ids = has_child_taxon_ids.map(&:parent_id)
    where id: parent_ids
  end

  def childrens
    self.class.where parent_id: self.id
  end

  def parent
    self.class.find_by id: self.parent_id
  end

  def self.group_products
    results = {}
    all.sort_by{|t| t.name.downcase}.each do |taxon|
      products = taxon.products.where('products.deleted_at is null')
      if products.count > 0
        results[taxon.name] = products.map(&:attributes)
      end
    end
    results
  end

  def self.sort_groups
    parent_taxons.map do |taxon|
      if taxon.childrens.count > 0
        taxon.attributes.merge(childrens: taxon.childrens.map(&:attributes))
      else
        taxon.attributes.merge(childrens: [])
      end
    end
  end

private

  def set_taxonomy_id
    self.update_column('taxonomy_id', self.id)
  end

  def set_display_on
    if self.parent_id.to_i > 0
      parent = self.class.find_by(id: self.parent_id.to_i)
      self.update_column('display_on', parent.display_on) if parent
    end
  end

end