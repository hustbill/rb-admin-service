class Roleship < ActiveRecord::Base

  validate :catalog_id, :source_role_id, :destination_role_id, presence: true,numericality: true
  belongs_to :role, foreign_key: 'source_role_id'

  #before_save :check_destination_role_id

private

  def check_destination_role_id
    self.destination_role_id = self.source_role_id
  end

end