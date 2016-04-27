require 'shipstation'
require 'action_view/helpers/sanitize_helper.rb'
module API
  class ShipStationApi
    include ActionView::Helpers::SanitizeHelper

    def initialize
      @client = ShipStation::Client.new(
        APICONFIG[:ship_station_api], 
        APICONFIG[:ship_station_account], 
        APICONFIG[:ship_station_password])
    end
    
    def find(number)
      @client.orders.where(OrderNumber: number)
    end

    def shipped(real_order, provider_name)
      ss_order = @client.order.create(
        StoreID: APICONFIG[:ship_station_store_id],
        OrderNumber: real_order.number,
        ImportKey: "OrderID#{real_order.id}",
        OrderDate: real_order.order_date,
        PayDate: real_order.order_date,
        OrderStatusID: 2,
        RequestedShippingService: provider_name,
        OrderTotal: real_order.total,
        AmountPaid: real_order.payment_total,
        ShippingAmount: real_order.adjustments.select{|aa| aa["label"] == "Shipping" }[0].try(:amount),
        TaxAmount:      real_order.adjustments.select{|aa| aa["label"] == "sales_tax"}[0].try(:amount),
        NotesFromBuyer: "Please make sure it gets here by Monday!",
        InternalNotes: "Expedite this order.",
        BuyerName: real_order.user.login,
        BuyerEmail: real_order.user.email,
        ShipName: "#{real_order.ship_address.firstname} #{real_order.ship_address.lastname}",
        ShipCompany: "",
        ShipStreet1: real_order.ship_address.address1,
        ShipCity: real_order.ship_address.city,
        ShipState: real_order.ship_address.state.name,
        ShipPostalCode: real_order.ship_address.zipcode,
        ShipCountryCode: real_order.ship_address.country.iso,
        ShipPhone: real_order.ship_address.phone,
        AddressVerified: 0,
        MarketplaceID: 0,
        InsuranceProvider: 0,
        Confirmation: 0)
      real_order.line_items.each do |item|
        # next if item.product.taxons.map{|t| t.name.downcase }.include?("system")
        @client.order_item.create(
          OrderID: ss_order.OrderID,
          SKU: item.variant.sku,
          Description: item.product.name,
          WeightOz: item.variant.weight,
          Quantity: item.quantity,
          UnitPrice: item.price,
          Options: item.line_items_personalized_values.map{|val| "#{val.personalized_name}: #{val.personalized_value}" }.join(' '))
      end
      ss_order
    end

    def shipping_providers
      # @client.ShippingServices.all.map{|sp| [sp.Name, sp.ShippingServiceID]}
      @client.ShippingProviders.all.map{|sp| sp.Name}
    end

  end

end
    
