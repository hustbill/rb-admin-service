module V1
  class Orders < ::BaseAPI
    version 'v1', using: :path
    namespace "admin" do

      helpers OrderHelper

      desc 'orders/index'
      params do
        optional :limit, :type => Integer, :default => 25
        optional :offset, :type => Integer, :default => 0
        optional :number, :type => String, :default => nil
        optional :shipment_state, :type => String, :default => nil
        optional :order_state, :type => String, :default => nil
        optional :order_date, :type => String, :default => nil
        optional :payment_method, :type => String, :default => nil
        optional :sku, :type => String, :default => nil
        optional :product_name, :type => String, :default => nil
      end
      get 'orders' do
        search = ::Order
          .search(params[:q])
          .result
          .by_order_date(params[:order_date])
          .by_number(params[:number])
          .by_order_state(params[:order_state])
          .by_shipment_state(params[:shipment_state])
          .by_payment_method(params[:payment_method])
          .by_sku(params[:sku])
          .by_product_name(params[:product_name])
          .order("orders.order_date desc")
        orders = search.limit(params[:limit]).offset(params[:offset])
        generate_success_response( build_response_orders(orders, search.count) )
      end

      desc 'warehoses/index'
      params do
        optional :limit, :type => Integer, :default => 25
        optional :offset, :type => Integer, :default => 0
        optional :number, :type => String, :default => nil
        optional :shipment_state, :type => String, :default => nil
        optional :order_state, :type => String, :default => nil
        optional :order_date, :type => String, :default => nil
      end
      get 'orders/warehouse' do
        search = ::Order
          .where.not(state: 'payment')
          .where(shipment_state: ['ready', 'assemble', 'shipped'])
          .where(params[:country_id].present? ? ['addresses.country_id = ?', params[:country_id].to_i] : nil)
          .by_order_date(params[:order_date])
          .by_number(params[:number])
          .by_order_state(params[:order_state])
          .by_shipment_state(params[:shipment_state])
          .order("id desc")
          .select("orders.*, coalesce(addresses.firstname || ' ' || addresses.lastname, '') as shipto_name, users.login as entered_by")
          .joins("LEFT JOIN addresses ON (orders.ship_address_id = addresses.id)")
          .joins("LEFT JOIN users ON (orders.entry_operator = users.id)")
          .joins('left join countries c on addresses.country_id = c.id')
        orders = search.limit(params[:limit]).offset(params[:offset])
        generate_success_response( build_response_orders(orders, search.count) )
      end

      desc 'warehoses/orders_download.'
      params do
        optional :limit, :type => Integer, :default => 25
        optional :offset, :type => Integer, :default => 0
        optional :number, :type => String, :default => nil
        optional :order_date, :type => String, :default => nil
      end
      get 'orders/download' do
        search = ::Order
          .where(shipment_state: 'ready')
          .by_number(params[:number])
          .by_order_date(params[:order_date]||Time.now().strftime("%Y-%m-%d").to_s)
          .order("id desc")
        orders = search.limit(params[:limit]).offset(params[:offset])
        generate_success_response( build_response_orders(orders, search.count) )
      end

      desc 'generate PDF invoices'
      params do
        requires :ids, :type => String, :desc => "order ids string(1001,1002,1003,...)"
      end
      get 'pdf_invoices' do

        company_code = request_info[:headers]["X-Company-Code"]
        pdf = make_pdfs(params[:ids], company_code)
        r = {:pdf => Base64.encode64(pdf.render)}
        generate_success_response(r)
      end

      desc 'query orders and generate to PDF invoices'
      params do
        requires :ids, :type => Array, :desc => "order ids Array[1001,1002,1003,...]"
        optional :shipment_state, :type => String, :default => nil
        optional :order_state, :type => String, :default => nil
        optional :order_date, :type => String, :default => nil
      end
      post 'orders2pdf' do
        # FIXME: put all query in q
        company_code = request_info[:headers]["X-Company-Code"]
        @orders = ::Order
          .where("id in (?)", params[:ids])
          .by_order_date(params[:order_date])
          .by_number(params[:number])
          .by_order_state(params[:order_state])
          .by_shipment_state(params[:shipment_state])
        order_ids_str = @orders.map(&:id).sort.join(',')
        pdf = make_pdfs(order_ids_str, company_code)
        r = {:pdf => Base64.encode64(pdf.render)}
        generate_success_response(r)
      end

      desc 'show order detail'
      params do
         requires :id, type: Integer
      end
      get "orders/:id" do
        @order = Order.find(params[:id])
        r = {
          "detail" => @order.decorated_attributes,
          "currency" => @order.currency.iso_code,
          "line-items" => @order.line_items.map(&:decorated_attributes),
          "adjustments" => @order.adjustments.map(&:decorated_attributes),
          "payments" => @order.payments.map(&:decorated_attributes),
          "shipping-address" => (@order.ship_address.nil? ? {} : @order.ship_address.decorated_attributes),
          "billing-address" => (@order.bill_address.nil? ? {} : @order.bill_address.decorated_attributes),
          "shipments" => @order.shipments.map(&:decorated_attributes),
          "notes" => (@order.admin_notes.nil? ? {} : @order.admin_notes.map(&:decorated_attributes))
        }
        generate_success_response(r)
      end

      desc 'update line item q_volume'
      params do
        requires :id, type: Integer
      end
      post "orders/update_line_item/:id" do
        li = LineItem.find(params[:id])
        res = 'not found'

        if li
          res = 'invalid field or value'

          if params[:adj_cv] && li.u_volume + params[:adj_cv].to_f >= 0
            begin
              li.update(adj_cv: params[:adj_cv])
              LineItem.delete_processed_id(li.order_id)
              res = 'done'
            rescue
              res = 'column not exists'
            end
          end

          if params[:adj_qv] && li.q_volume + params[:adj_qv].to_f >= 0
            begin
              li.update(adj_qv: params[:adj_qv])
              LineItem.delete_processed_id(li.order_id)
              res = 'done'
            rescue
              res = 'column not exists'
            end
          end
        end

        generate_success_response(res)

      end

      desc 'get currency'
      get "orders/:id/get_currency" do
        @order = Order.find(params[:id])
        r = {
          "code" => @order.currency.iso_code,
          "symbol" => @order.currency.symbol
        }
        generate_success_response(r)
      end
      # desc 'all orders for download file'
      # params do
      #   requires :shipment_state, type: String, desc: 'shipment state'
      # end
      # post 'all_orders' do
      #   orders = Order.by_shipment_state(params[:shipment_state])
      #   generate_success_response( build_response_orders(orders) )
      # end

      desc 'payments capture'
      params do
        requires :id, type: Integer
      end
      post "payments/:id/capture" do
        payment = Payment.find(params[:id])
        if payment.nil? || payment.payment_method.type != "PaymentMethod::Cash" || payment.state != "pending" || payment.order.payment_state != "balance_due" || payment.order.state != "complete"
          generate_success_response(success: false, message: "Can't capture!", :"order-id" => payment.order.id )
        else
          payment.capture
          generate_success_response(success: true, message: "Capture Success", :"order-id" => payment.order.id )
        end
      end

      desc "back date orders"
      params do
        requires :order_numbers, type: Array
      end
      post "orders/back_date" do
        orders = Order.where(number: params["order_numbers"])
        orders_columns = orders.select("number,order_date")
        not_found = params["order_numbers"] - orders.map{|oo| oo.number }
        forced = []
        errors = []
        orders.each do |o|
          order_info = o.force_date(params["order_date"])
          forced << order_info.first if order_info.first.present? && order_info.last.blank?
          errors << order_info.last if order_info.last.present?
        end if params["force"] == "true"
        rrr = {
          orders: orders_columns,
          not_found: not_found,
          forced: forced,
          errors: errors
        }
        generate_success_response( rrr )
      end

      desc "ship order to shipstation"
      params do
        requires :id, type: Integer
        requires :provider, type: String
      end
      post "orders/:id/shipped" do
        order = Order.where(id: params[:id]).includes(:user, ship_address: [:country, :state]).first
        ss = API::ShipStationApi.new
        if ss.find(order.number).present?
          raise "Order have existed."
        else
          # NOTE:
          # order has_one shipment for now.
          # push order to ss when it has shipments
          # liwei 2014-6-16
          shipment = order.shipments.first
          if shipment
            rrr = ss.shipped(order, params[:provider])
            order.update(shipment_state: "assemble")
            shipment.update(state: "assemble")
            order.state_events.create(
              user_id: order.user_id,
              name: "shipment",
              previous_state: shipment.state || "",
              next_state: "assemble")
            generate_success_response( rrr )
          else
            raise "No shipments of order"
          end
        end
      end

      desc "shipping providers"
      params do
      end
      post "orders/shipping_providers" do
        ss = API::ShipStationApi.new
        generate_success_response( ss.shipping_providers )
      end

      desc "create note by order id"
      post "orders/:id/create-note" do
        order = Order.where(id: params[:id]).first
        if order.present?
          note = order.admin_notes.build note: params[:note], user_id: headers["X-User-Id"]
          if note.save
            generate_success_response(
              order.admin_notes.reload.map(&:decorated_attributes)
            )
          else
            generate_error_response('error')
          end
        else
          raise "Not Found"
        end
      end
    end
  end
end
