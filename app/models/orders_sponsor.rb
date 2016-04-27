class OrdersSponsor < ActiveRecord::Base
  belongs_to :order
  belongs_to :distributor, class_name: 'Distributor', foreign_key: 'sponsor_id'

end