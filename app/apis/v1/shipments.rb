module V1
  class Shipments < ::BaseAPI
    version 'v1', using: :path
    namespace "admin" do
      helpers OrderHelper
      namespace "shipments" do
        desc "toship orders"
        params do
        end
        get "toship_orders" do
          orders = Shipment.toship_orders(params)
          generate_success_response( build_shipment_orders(orders) )
        end
        
        desc "toship orders assemble"
        params do
        end
        get "toship_orders_assemble" do
          orders = Shipment.toship_orders_assemble(params)
          generate_success_response( build_shipment_orders(orders) )
        end

        desc "shipment byitem"
        params do
        end
        get "shipment_byitem" do
          orders = Shipment.shipment_byitem(params)
          generate_success_response( build_shipment_orders(orders) )
        end

        desc "shipment byitem assemble"
        params do
        end
        get "shipment_byitem_assemble" do
          orders = Shipment.shipment_byitem_assemble(params)
          generate_success_response( build_shipment_orders(orders) )
        end

        desc "transit to assemble"
        params do
          requires :order_id_list, type: Array, desc: 'order id list'
        end
        post "transit_to_assemble" do
          Shipment.transit_to_assemble(params[:order_id_list])
          generate_success_response( "ok" )
        end

        desc "update tracking number"
        params do
        end
        post "update_tracking_number" do
          create_sql = "create table temp_shipment_info (
                        order_number varchar(255),
                        tracking_number varchar(255),
                        ship_via varchar(255),
                        weight_val numeric(8,2),
                        shipping_cost numeric(8,2),
                        shipping_date timestamp);"
          insert_sql = ""
          params[:tracking].each do |line|
            insert_sql += "INSERT INTO temp_shipment_info VALUES ('#{line[0]}', '#{line[1]}', '#{line[2]}', #{line[3]}, #{line[4]}, '#{line[5].to_date.strftime("%Y-%m-%d")}' ); "
          end
          select_sql = "select save_tracking();"
          drop_sql = "drop table temp_shipment_info;"
          ActiveRecord::Base.connection.execute(create_sql + insert_sql + select_sql + drop_sql)
          generate_success_response( "ok" )
        end

      end      
    end
  end
      
      
end
