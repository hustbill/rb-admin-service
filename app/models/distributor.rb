class Distributor < ActiveRecord::Base

  belongs_to :user
  belongs_to :sponsor_distributor, class_name: 'Distributor', foreign_key: 'personal_sponsor_distributor_id'

end

