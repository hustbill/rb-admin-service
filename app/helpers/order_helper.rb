module OrderHelper
  include ::ActionView::Helpers::NumberHelper

  # orders_id_str = "1,2,3,4,5....."
  def make_pdfs(orders_id_str, company_code)
    pdf = Prawn::Document.new(:skip_page_creation => true)
    count = 0
    orders_id_str.to_s.split(',').each do |id|
      order = Order.find_by_id(id.to_i)
      order_coupons = order.orders_coupons.joins(:coupon) if order.orders_coupons
      # order_coupons = order.orders_coupons.joins(:coupon).inject([]) do |result, item|
      #   JSON.parse(item.details)["lineItems"].each do |coupon|
      #     result << coupon
      #   end
      #   result
      # end
      next if order.blank? || order.ship_address.blank?

      pdf.start_new_page
      width = 540
      count += 1

      ##################### header ######################

      pdf.bounding_box([0, pdf.cursor], :width => width, :height => 90) do

        if company_code == "ZVI"
          warehouse_with = 180
          logo_with = 160
          logo_height = 70
          logo_left = 190
          order_info_left = 360
          logo_path = "#{Goliath.root}/app/assets/images/logo-zoivi.jpg"
        else
          warehouse_with = 140
          logo_with = 180
          logo_height = 70
          logo_left = 170
          order_info_left = 380
          case company_code
          when "MIO"
            logo_path = "#{Goliath.root}/app/assets/images/miioon_logo.png"
          when "FTO"
            logo_path = "#{Goliath.root}/app/assets/images/fto_logo.jpg"
          when "BEB"
            logo_path = "#{Goliath.root}/app/assets/images/beb_logo.jpg"
          when "WNP"
            logo_path = "#{Goliath.root}/app/assets/images/wnp_logo.png"
          else
            logo_path = "#{Goliath.root}/app/assets/images/default.png"
          end
        end

        # warehouse
        pdf.bounding_box([0, pdf.bounds.top], :width => warehouse_with) do
          order_legal_entity = order.legal_entity
          if order_legal_entity.present? && order_legal_entity.address.present?
            address = order_legal_entity.address
            state_abbr = address.state.nil? ? "" : "#{address.state.abbr}"
            country = address.country.nil? ? "" : "#{address.country.name}"
            phone_info = ""
            if address.phone.present?
              phone_info += "Phone: #{address.phone}"
            elsif address.mobile_phone.present?
              phone_info += "Phone: #{address.mobile_phone}"
            end
            pdf.font_size = 10
            pdf.text "#{order_legal_entity.name}"
            pdf.text "#{address.address1}"
            pdf.text "#{address.address2}" if address.address2.present?
            pdf.text "#{address.city}, #{state_abbr}, #{address.zipcode}"
            pdf.text "#{country}"
            pdf.text "#{phone_info}"
          end
        end

        # logo
        pdf.bounding_box([logo_left, pdf.bounds.top], :width => logo_with, :height => logo_height) do
          # pdf.stroke_color '000000'
          # pdf.stroke_bounds
          logo = logo_path
          pdf.image logo, :width => logo_with, :height => logo_height

        end

        # order information
        pdf.bounding_box([order_info_left, pdf.bounds.top], :width => 180) do
          info = [
            ["Order Number:"   , order.number],
            ["Invoice Number:" , order.number],
            ["Order Date:"     , order.order_date.strftime("%m/%d/%Y")]
          ]

          pdf.table info, :cell_style => {:align => :left, :borders => [], :size => 10} do
            column(0).align = :right
          end
        end
      end

      ##################### title #########################
      pdf.bounding_box([0, pdf.cursor - 10], :width => width, :height => 35) do
        pdf.text "Invoice", :align => :center, :size => 16, :style => :bold
        # pdf.text "*** RePrint ***", :align => :center, :size => 14
      end

      ##################### address #######################

      y_position = pdf.cursor
      pdf.bounding_box([0, pdf.cursor - 10], :width => width, :height => 110) do

        if order.bill_address.present?
          # bill address
          pdf.bounding_box([290, pdf.bounds.top - 10], :width => 250, :height => 100) do
            pdf.stroke_color '000000'
            pdf.stroke_bounds

            pdf.bounding_box([10, pdf.bounds.top - 10], :width => 240, :height => 90) do
              pdf.text "Billing Address", :size => 12, :style => :bold

              pdf.bounding_box([10, pdf.bounds.top - 20], :width => 230, :height => 70) do
                address = order.bill_address
                state_abbr = address.state.nil? ? "" : "#{address.state.abbr}"
                country = address.country.nil? ? "" : "#{address.country.name}"
                phone_info = ""
                if address.phone.present?
                  phone_info += "Phone: #{address.phone}"
                elsif address.mobile_phone.present?
                  phone_info += "Phone: #{address.mobile_phone}"
                end
                pdf.font_size = 10
                pdf.text "#{address.full_name}"
                pdf.text "#{address.address1}"
                pdf.text "#{address.address2}" if address.address2.present?
                str = [address.city, state_abbr, address.zipcode].select{|i| i.present? }.join(', ')
                pdf.text str
                pdf.text "#{country}"
                pdf.text "#{phone_info}"
              end
            end
          end
        end

        # ship address
        pdf.bounding_box([0, pdf.bounds.top - 10], :width => 250, :height => 100) do
          pdf.stroke_color '000000'
          pdf.stroke_bounds

          pdf.bounding_box([10, pdf.bounds.top - 10], :width => 240, :height => 90) do
            pdf.text "Shipping Address", :size => 12, :style => :bold

            pdf.bounding_box([10, pdf.bounds.top - 20], :width => 230, :height => 70) do
              address = order.ship_address
              state_abbr = address.state.nil? ? "" : "#{address.state.abbr}"
              country = address.country.nil? ? "" : "#{address.country.name}"
              phone_info = ""
              if address.phone.present?
                phone_info += "Phone: #{address.phone}"
              elsif address.mobile_phone.present?
                phone_info += "Phone: #{address.mobile_phone}"
              end
              pdf.font_size = 10
              pdf.text "#{address.full_name}"
              pdf.text "#{address.address1}"
              pdf.text "#{address.address2}" if address.address2.present?
              str = [address.city, state_abbr, address.zipcode].select{|i| i.present? }.join(', ')
              pdf.text str
              pdf.text "#{country}"
              pdf.text "#{phone_info}"
            end
          end
        end
      end

      ################### order details ###################

      # distributor info
      pdf.move_down 10
      user = order.user
      distributor = user.distributor
      shipping_method = order.shipping_method.present? ? order.shipping_method.name : ""
      commission_volume = CommissionVolume.find_by_order_id(order.id) rescue nil
      period = commission_volume ? (commission_volume.state_date.next_week + 4.days).strftime("%m/%d/%Y") : ""  #next friday.
      entry_date = order.order_date.strftime("%m/%d/%Y")
      #entry_time = order.order_date.strftime("%H:%M")
      distributor_info = [
        ["<u>Distributor ID</u>", "<u>Name</u>", "<u>Period</u>", "<u>Ship Via</u>", "<u>Entry Date</u>", ""],
        [distributor.try(:id), distributor.user.name , period, shipping_method, entry_date, ""]
      ]
      pdf.table distributor_info, :width => width, :cell_style => {:align => :center, :borders => []},
                :column_widths => [100 ,100 ,80, 160, 80, 20] do |t|
        t.row(0).borders = [:top]; t.row(-1).borders = [:bottom]; t.column(0).borders = [:left]; t.column(-1).borders = [:right]
        t.row(0).column(0).borders = [:top, :left]; t.row(0).column(-1).borders = [:top, :right]
        t.row(-1).column(0).borders = [:bottom, :left]; t.row(-1).column(-1).borders = [:bottom, :right]
        t.row(0).inline_format = true
        t.row(0).font_style = :bold
      end

      # lineitems
      table_data = []
      if company_code == 'BEB' && order.user.roles.first.role_code == 'R'
        table_data << ["Item Code", "Description", "Quantity Ordered", "Item Price", "Total Price"]
      else
        table_data << ["Item Code", "Description", "Quantity Ordered", "Item PV", "Total PV", "Item Price", "Total Price"]
      end
      total_volume = 0.0
      order.line_items.includes(:variant, :product).each do |item|
        coupon_description = ''
        order_coupons.each do |order_coupon|
          detail = JSON.parse(order_coupon.details)["lineItems"]
          if detail.present?
            detail.each do |line_item|
              if line_item.present? &&  item.variant_id == line_item["variantId"] && item.quantity == line_item["quantity"] && (item.adj_qv.to_f + item.q_volume.to_f) == 0
                coupon_description = "(#{order_coupon.coupon.description})"
                break;
              end
            end
          end
          break if coupon_description.present?
        end
        item_description = item.variant.product.name + coupon_description
        if CompanyConfig::CONFIG["enable_personalized_type"] && item.line_items_personalized_values.present?
          personalized_values = ""
          item.line_items_personalized_values.each do |v|
            personalized_values << "<br/>#{v.personalized_name}: #{v.personalized_value}"
          end
          item_description << personalized_values
        end
        row = []
        row << item.variant.sku
        row << Prawn::Table::Cell::Text.new(pdf, [0,0], :content => item_description,:inline_format => true)
        row << item.quantity
        if company_code != 'BEB' || order.user.roles.first.role_code != 'R'
          row << "%.2f" % (item.q_volume.to_f / item.quantity)
          row << "%.2f" % item.q_volume.to_f
        end
        row << "%.2f" % item.price.to_f + " " + order.currency.iso_code
        row << "%.2f" % (item.price.to_f * item.quantity) + " " +order.currency.iso_code
        table_data << row

        item.variant.product_boms.each do |bom|
          if bom.isactive
            bom_variant = Variant.find(bom.variantbom_id) rescue nil
            if bom_variant.present?
              if company_code != 'BEB' || order.user.roles.first.role_code != 'R'
                table_data << ["", "\u00AD      " + bom_variant.product.name[0..9] + "... x " + bom.bomqty.to_i.to_s, "", "", "", "", "",]
              else
                table_data << ["", "\u00AD      " + bom_variant.product.name[0..9] + "... x " + bom.bomqty.to_i.to_s, "", "", "",]
              end
            end
          end
        end
        total_volume += item.q_volume.to_f
      end

      if company_code == 'BEB' && order.user.roles.first.role_code == 'R'
        pdf.table table_data, :width => width, :cell_style => {:borders => [:left, :right], :align => :right}, :column_widths => [100, 160, 100, 90, 90] do |t|
          t.row(0).borders = [:left, :top, :right, :bottom]
          t.row(-1).borders = [:left, :right, :bottom]
          t.columns(0..1).align = :left
          t.row(0).font_style = :bold
        end
      else
        pdf.table table_data, :width => width, :cell_style => {:borders => [:left, :right], :align => :right}, :column_widths => [100, 150, 50, 50, 50, 70, 70] do |t|
          t.row(0).borders = [:left, :top, :right, :bottom]
          t.row(-1).borders = [:left, :right, :bottom]
          t.columns(0..1).align = :left
          t.row(0).font_style = :bold
        end
      end

      #prawn-grouping start
      pdf.group do |g|

        # summary
        g.move_down 10
        top = g.cursor
        g.bounding_box([0, g.cursor], :width => width) do

          # left
          g.bounding_box([10, g.bounds.top], :width => 180) do
            table_data = []
            table_data << ["Comments", ""]
            g.table table_data, :cell_style => {:align => :left, :borders => []} do |t|
              t.row(0).column(0).font_style = :bold
              t.row(-1).column(0).align = :right
            end
          end

          # total volume
          g.bounding_box([190, g.bounds.top], :width => 180) do
            if company_code != 'BEB' || order.user.roles.first.role_code != 'R'
              table_data = []
              table_data << ["Total Volume", "%.2f" % total_volume]
              g.table table_data, :cell_style => {:align => :right, :borders => []}
            end
          end

          # right summary
          g.bounding_box([370, g.bounds.top], :width => 170) do
            table_data = []
            sub_total = order.total.to_f
            order.adjustments.each do |adjustment|
                sub_total = sub_total - adjustment.amount.to_f
            end
            if company_code == 'BEB' && order.ship_address.country_id == 1012
              table_data << ["SubTotal", "%.2f" % (sub_total.to_f / 1.1) + " " + order.currency.iso_code]
              table_data << ["GST", "%.2f" % (sub_total.to_f / 11) + " " + order.currency.iso_code]
            else
              table_data << ["SubTotal", "%.2f" % sub_total.to_f + " " + order.currency.iso_code]
            end
            order.adjustments.sort_by{|a| a.label.titleize}.each do |adjustment|
              #sort label title so that Sales Tax comes before Shipping according to customer request
              table_data << [adjustment.label.titleize, "%.2f" % adjustment.amount.to_f + " " + order.currency.iso_code]
            end
            table_data << ["Total", "%.2f" % order.total.to_f + " " + order.currency.iso_code]
            amount_due = order.total.to_f - order.payment_total.to_f
            table_data << ["Amount Paid", "%.2f" % order.payment_total.to_f + " " + order.currency.iso_code]
            table_data << ["Amount Balance", "%.2f" % amount_due + " " + order.currency.iso_code]
            table_data << ["Payment Method", (order.payments.completed.present? ? order.payments.completed.first.payment_method.name : '')]

            g.table table_data, :width => 160, :cell_style => {:align => :right, :borders => []} do |t|
              t.row(-5).borders = [:bottom]
              t.row(-5).border_width = 2
            end
          end
        end
        bottom = g.cursor
        # fixed bounding_box auto height bug
        g.bounding_box([0, top], :width => width, :height => top - bottom) do
          g.stroke_color '000000'
          g.stroke_bounds
        end
      end
      #prawn-grouping end

      #prawn-grouping start
      pdf.group do |g|
        # special instructions
        g.move_down 10
        g.bounding_box([0, g.cursor], :width => width, :height => 100) do
          g.stroke_color '000000'
          g.stroke_bounds

          g.bounding_box([10, g.cursor - 10], :width => width - 10) do
            g.text "Special Instructions:" + order.special_instructions.to_s
          end
        end
      end
      #prawn-grouping end
    end
    pdf
  end

  def build_response_orders(collection, total)
    orders_count = total
    orders = collection.map do |o|
      #dt_volume + u_volume => CV
      #q_volume => QV
      cv = 0
      qv = 0
      o.line_items.each do |l|
        cv += (l.dt_volume.to_f + l.u_volume.to_f + l.adj_cv.to_f rescue l.dt_volume.to_f + l.u_volume.to_f)
        qv += (l.q_volume.to_f + l.adj_qv.to_f rescue l.q_volume.to_f)
      end
      {
        "id" => o.id,
        "number" => o.number,
        "order-date" => o.order_date.to_date,
        "total" => o.total,
        "currency" => (o.ship_address.country.currency.iso_code rescue ""),
        "payment-total" => o.payment_total,
        "state" => o.state,
        "payment-state" => o.payment_state,
        "shipment-state" => o.shipment_state,
        "shipping-method" => o.shipping_method.try(:name),
        "user-id" => o.user_id,
        "distributor-id" => (o.user.distributor.id rescue nil),
        "distributor-name" => (o.user.name rescue nil),
        "login" => (o.user.login rescue nil),
        "sponsor-id" => (o.user.login == 'GUEST_USER' ? o.orders_sponsor.sponsor_id : o.user.distributor.sponsor_distributor.id rescue nil),
        "sponsor-name" => (o.user.login == 'GUEST_USER' ? o.orders_sponsor.distributor.user.name : o.user.distributor.sponsor_distributor.user.name rescue nil),
        "qualification-volume" => ('%.2f' % qv.to_f),
        "commission-volume" => ('%.2f' % cv.to_f),
        "shipto-name" => o.try(:shipto_name),
        "entry-operator" => (o.entry_user.name rescue nil),
        "completed-at" => o.completed_at,
        "country" => (o.ship_address.country.name rescue nil)
      }
    end
    {
      "meta" => {
        :count => orders_count,
        :limit => params[:limit],
        :offset => params[:offset]
      },
      "orders" => orders
    }
  end

    # {
    # "shipment_number"=>"H-Z00000011286-001",
    # "package_count"=>"1",
    # "order_id"=>"11286",
    # "order_number"=>"Z00000011286",
    # "order_date"=>"2014-03-24",
    # "warehouse_name"=>"ZVI Main Warehouse",
    # "shipto_name1"=>"Engels Almanzar",
    # "shipto_name2"=>"",
    # "shipto_address1"=>"601 West 185th Street",
    # "shipto_address2"=>"Apt 3E",
    # "shipto_city"=>"NY",
    # "shipto_state"=>"NY",
    # "shipto_zip"=>"10033",
    # "shipto_country"=>"US",
    # "shipto_phone"=>"(917)322.1042",
    # "shipto_email"=>"engels402@aol.com",
    # "home_name1"=>"Engels Almanzar",
    # "home_name2"=>"",
    # "home_address1"=>"601 West 185th Street",
    # "home_address2"=>"Apt 3E",
    # "home_city"=>"NY",
    # "home_state"=>"NY",
    # "home_zip"=>"10033",
    # "home_country"=>"US",
    # "home_phone"=>"(347) 882-9646",
    # "distributor_id"=>"130701",
    # "delivery_method"=>"Regular Ground 3-5 Days",
    # "weight"=>nil,
    # "invoice_total"=>"106.26",
    # "freight"=>"9.36",
    # "shipment_created_at"=>"2014-03-24",
    # "reference"=>nil,
    # "special_instructions"=>nil}
  def build_shipment_orders(collection)
    orders_count = collection.count
    orders = collection.map do |o|
      {
        "order_id" => o["order_id"],
        "shipment_number" => o["shipment_number"],
        "package_count" => o["package_count"],
        "order_number" => o["order_number"],
        "order-date" => o["order_date"],
        "warehouse_name" => o["warehouse_name"],
        "shipto_name1" => o["shipto_name1"],
        "shipto_name2" => o["shipto_name2"],
        "shipto_address1" => o["shipto_address1"],
        "shipto_address2" => o["shipto_address2"],
        "shipto_city" => o["shipto_city"],
        "shipto_state" => o["shipto_state"],
        "shipto_zip" => o["shipto_zip"],
        "shipto_country" => o["shipto_country"],
        "shipto_phone" => o["shipto_phone"],
        "shipto_email" => o["shipto_email"],
        "distributor_id" => o["distributor_id"],
        "delivery_method" => o["delivery_method"],
        "shipment_created_at" => o["shipment_created_at"],
        "weight" => o["weight"],
        "invoice_total" => o["invoice_total"],
        "freight" => o["freight"],
        "reference" => o["reference"],
        "line_number" => o["line_number"],
        "item_code" => o["item_code"],
        "quantity" => o["quantity"],
        "item_name" => o["item_name"],
        "item_description" => o["item_description"],
        "special_instructions" => o["special_instructions"],
      }
    end
    {
      "meta" => {
        :count => orders_count,
      },
      "orders" => orders
    }
  end
end
