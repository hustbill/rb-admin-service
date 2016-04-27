require 'carrierwave/orm/activerecord'

class Image < Asset
  before_save :set_attachment_content_type
  mount_uploader :attachment_file_name, ::ProductUploader

  STYLES = %w{mini small product large list_thumb}

  def extension_white_list
    %w(jpg jpeg gif png)
  end

  def decorated_attributes
    {
      id:   self.id,
      path: attachment_file_name.small.path,
      position: self.position
    }
  end

  private
  def set_attachment_content_type
    self.attachment_content_type = "image/jpeg"
  end

end
