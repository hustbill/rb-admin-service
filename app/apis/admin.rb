class Admin < Grape::API

  mount V1::Orders
  mount V1::Users
  mount V1::Autoships
  mount V1::Shipments
  mount V1::Products
  mount V1::Catalogs
  mount V1::Roles
  mount V1::Variants
  mount V1::Commissions
  mount V1::OptionValues
  mount V1::Assets
  mount V1::ImageGroups
  mount V1::Reports
  mount V1::PersonalizedTypes
  mount V1::Taxons
  mount V1::ShippingMethods
  mount V1::GiftCards
  mount V1::BankInfos
  mount V1::InterestedCustomers
  mount V1::Coupons
  mount V1::CouponProductGroups
  mount V1::CompanyNews
  mount V1::Communities
  mount V1::Preferences

end