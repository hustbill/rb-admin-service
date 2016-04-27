class ImageGroup < ActiveRecord::Base
  validate :name, presence: true
  validates_uniqueness_of :name

  has_many :assets

  scope :owner_product, ->{ where(source_type: 'Product') }

  before_save :filter_name
  after_commit :remove_assets, on: :destroy


private

  def filter_name
    self.name = self.name.strip
  end

  def remove_assets
    Asset.where(image_group_id: self.id).update_all(image_group_id: nil)
  end


end