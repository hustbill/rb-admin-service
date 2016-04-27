class OptionType < ActiveRecord::Base

  has_many :option_values

  validate :name, presence: true
  validates_uniqueness_of :name

  def product_option_values
    result = []
    active_option_values.each do |ov|
      if ov.respond_to?(:presentation_type) && ov.presentation_type == 'IMG'
        result << {image_path: (ov.image.attachment_file_name.small.path rescue nil), option_value_name: ov.name}
      else
        result << ov.name
      end
    end
    result
  end

  def active_option_values
    option_values.where(deleted_at: nil)
  end

end