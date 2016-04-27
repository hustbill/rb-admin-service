require 'carrierwave/orm/activerecord'

class CompanyNewsDescription < Asset
  before_save :set_attachment_content_type
  mount_uploader :attachment_file_name, ::ImageDescriptionUploader

  STYLES = %w{small}

  def extension_white_list
    %w(jpg jpeg gif png)
  end

  def decorated_attributes
    {
      id:   self.id,
      path: attachment_file_name.path,
      position: self.position
    }
  end

  private
  def set_attachment_content_type
    self.attachment_content_type = "image/jpeg"
  end

end