class InventoryUnit < ActiveRecord::Base
  belongs_to :variant
  belongs_to :order
  belongs_to :shipment
end