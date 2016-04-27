class UserTrack < ActiveRecord::Base

  belongs_to :user
  has_one    :distributor, foreign_key: 'user_id', primary_key: 'user_id'


  def decorated_attributes
    {
      id:      self.id,
      user_id: self.user_id,
      distributor_id: self.user.try(:distributor).try(:id),
      user_name: self.user.try(:login),
      name:      self.user.try(:name),
      sign_in_time: self.sign_in_at.to_s(:db),
      sign_in_ip:   self.sign_in_ip
    }
  end

end

