class Community < ActiveRecord::Base
  self.table_name = 'misc.communities'
  has_one :community_image, as: :viewable, dependent: :destroy
  before_save :set_community_type
  
  def set_community_type
    self.community_type = "banner" if community_type.nil?
  end

  def decorated_attributes
    {
      'id'          => id,
      'link'        => link,
      "summary" => summary,
      "community_type" => community_type,
      "image" => (
                  {
                    'small' => community_image.attachment_file_name.small.path,
                    'normal' => community_image.attachment_file_name.path,
                  } rescue nil
                ),
      "created-at"  => created_at
    }
  end
end