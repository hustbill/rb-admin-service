class PersonalizedTypesProduct < ActiveRecord::Base
  self.primary_key = 'personalized_type_id'
  belongs_to :personalized_type
end