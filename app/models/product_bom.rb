class ProductBom < ActiveRecord::Base

   belongs_to :variant
   belongs_to :bom_variant, class_name: 'Variant', foreign_key: 'variantbom_id'

   def deleted?
     ! self.isactive
   end

   def decorated_attributes
     {
       "variant_id" => variant_id,
       "variantbom_id" => variantbom_id,
       "bomqty" => bomqty,
     }
   end
end
# == Schema Information
#
# Table name: product_boms
#
#  id                    :integer         not null, primary key
#  isactive              :boolean
#  createdby             :string(32)
#  updatedby             :string(10)
#  line                  :integer(18)
#  variant_id            :integer
#  variantbom_id         :integer
#  bomqty                :decimal(18, 2)
#  description           :string(255)
#  bomtype               :string(60)
#  shippingfeeapplicable :boolean
#  created_at            :datetime
#  updated_at            :datetime
#
