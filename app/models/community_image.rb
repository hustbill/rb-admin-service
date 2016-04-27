require 'carrierwave/orm/activerecord'

class CommunityImage < Asset
  before_save :set_attachment_content_type
  mount_uploader :attachment_file_name, ::CommunityImageUploader

  STYLES = %w{small}

  def extension_white_list
    %w(jpg jpeg gif png)
  end

  private
  def set_attachment_content_type
    self.attachment_content_type = "image/jpeg"
  end

end