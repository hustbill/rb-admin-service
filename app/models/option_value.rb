class OptionValue < ActiveRecord::Base

  belongs_to :option_type
  has_one :image, as: :viewable, dependent: :destroy

  validate :name, :presentation_type, :presentation_value, presence: true
  validates_uniqueness_of :name

  after_commit :update_image_path, on: [:create, :update]

  def decorated_attributes
    if self.respond_to?(:presentation_type) && self.presentation_type == 'IMG'
      attributes.merge(image: (image.attachment_file_name.small.path rescue nil))
    else
      attributes
    end
  end

private

  def update_image_path
    if self.respond_to?(:presentation_type) && self.presentation_type == 'IMG'
      self.update_column('presentation_value', image.try(:attachment_file_name).try(:mini_thumb).try(:path))
    end
  end

end