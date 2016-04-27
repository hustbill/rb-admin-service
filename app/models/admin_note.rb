class AdminNote < ActiveRecord::Base
  belongs_to :user,  polymorphic: true
  belongs_to :order, polymorphic: true
  belongs_to :operator, class_name: 'User', :foreign_key => 'user_id'

  def decorated_attributes
    {
      "id" => id,
      "note" => note,
      "user-name" => self.operator.name,
      "created-at" => created_at
    }
  end
end