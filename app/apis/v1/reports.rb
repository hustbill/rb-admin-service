module V1
  class Reports < ::BaseAPI
    helpers ::ReportsHelpers
    version 'v1', using: :path

    namespace 'admin' do

      desc 'top ten products'
      params do
        optional :limit, :type => Integer, :default => 25
        optional :page, :type => Integer, :default => 1
      end
      get 'reports/top_ten_products' do
        @search = top_ten_products(params)
        if params[:search_type].blank?
          @reports = @search[(params[:page]-1)*params[:limit]..params[:page]*params[:limit]-1]
        else
          @reports = @search
        end
        @summary = {
          "adj" => @search.map{|a| (a[:cost].to_f * a[:quantity].to_i) }.sum.round(2),
          "ret" => @search.map{|a| a[:total].to_f }.sum.round(2),
          "quan" => @search.map{|a| a[:quantity].to_i }.sum
        }
        r = {
          "meta" => {
            :count => @search.count,
            :limit => params[:limit],
            :offset => (params[:page]-1)*params[:limit]
          },
          "reports" => @reports,
          "summary" => @summary
        }
        generate_success_response(r)
      end

      desc 'sales report'
      params do
        optional :limit, :type => Integer, :default => 25
        optional :page, :type => Integer, :default => 1
      end
      get 'reports/sales_report' do
        @search = sales_report(params)
        @reports = @search[(params[:page]-1)*params[:limit]..params[:page]*params[:limit]-1]
        @summary = {
          "item_total_sum" => @search.map{|a| ( a["item_total"].nil? ? 0.0 : a["item_total"].to_f ) }.sum.round(2),
          "adjustment_total_sum" => @search.map{|a| ( a["adjustment_total"].nil? ? 0.0 : a["adjustment_total"].to_f ) }.sum.round(2),
          "payment_total_sum" => @search.map{|a| ( a["payment_total"].nil? ? 0.0 : a["payment_total"].to_f ) }.sum.round(2),
          "total_sum" => @search.map{|a| ( a["total"].nil? ? 0.0 : a["total"].to_f ) }.sum.round(2),
          "freight_sum" => @search.map{|a| ( a[:freight].nil? ? 0.0 : a[:freight].to_f ) }.sum.round(2),
          "sales_tax_sum" => @search.map{|a| ( a[:sales_tax].nil? ? 0.0 : a[:sales_tax] ).to_f }.sum.round(2)
        }
        r = {
          "meta" => {
            :count => @search.count,
            :limit => params[:limit],
            :offset => (params[:page]-1)*params[:limit]
          },
          "reports" => @reports,
          "summary" => @summary
        }
        generate_success_response(r)
      end

      desc 'enrollment'
      params do
        optional :limit, :type => Integer, :default => 25
        optional :page, :type => Integer, :default => 1
      end
      get 'reports/enrollment' do
        @search = Report.enrollment(params)
        @reports = @search[(params[:page]-1)*params[:limit]..params[:page]*params[:limit]-1]
        r = {
          "meta" => {
            :count => @search.count,
            :limit => params[:limit],
            :offset => (params[:page]-1)*params[:limit]
          },
          "reports" => @reports
        }
        generate_success_response(r)
      end

      desc 'sales by product'
      params do
        optional :limit, :type => Integer, :default => 25
        optional :page, :type => Integer, :default => 1
      end
      get 'reports/sales_by_product' do
        @search = Report.sales_by_product(params)
        @reports = @search[(params[:page]-1)*params[:limit]..params[:page]*params[:limit]-1]
        r = {
          "meta" => {
            :count => @search.count,
            :limit => params[:limit],
            :offset => (params[:page]-1)*params[:limit]
          },
          "reports" => @reports
        }
        generate_success_response(r)
      end

      desc 'shipping charge'
      params do
        optional :limit, :type => Integer, :default => 25
        optional :page, :type => Integer, :default => 1
      end
      get 'reports/shipping_charge' do
        @search = Report.shipping_charge(params)
        @reports = @search[(params[:page]-1)*params[:limit]..params[:page]*params[:limit]-1]
        r = {
          "meta" => {
            :count => @search.count,
            :limit => params[:limit],
            :offset => (params[:page]-1)*params[:limit]
          },
          "reports" => @reports
        }
        generate_success_response(r)
      end

      desc 'sales items'
      params do
        optional :limit, :type => Integer, :default => 25
        optional :page, :type => Integer, :default => 1
      end
      get 'reports/sales_items' do
        @search = Report.sales_items(params)
        @reports = @search[(params[:page]-1)*params[:limit]..params[:page]*params[:limit]-1]
        r = {
          "meta" => {
            :count => @search.count,
            :limit => params[:limit],
            :offset => (params[:page]-1)*params[:limit]
          },
          "reports" => @reports
        }
        generate_success_response(r)
      end

      desc 'volume 6 months'
      params do
        optional :limit, :type => Integer, :default => 25
        optional :page, :type => Integer, :default => 1
        optional :order, :type => String, :default => 'Personal Volume'
      end
      get 'reports/volume_6m' do
        @search = Report.volume_6m(params)
        @reports = @search[(params[:page]-1)*params[:limit]..params[:page]*params[:limit]-1]
        r = {
          "meta" => {
            :count => @search.count,
            :limit => params[:limit],
            :offset => (params[:page]-1)*params[:limit]
          },
          "reports" => @reports
        }
        generate_success_response(r)
      end

      desc 'sales by person'
      params do
        optional :limit, :type => Integer, :default => 25
        optional :page, :type => Integer, :default => 1
      end
      get 'reports/sales_by_person' do
        @search = Report.sales_by_person(params)
        raw = @search[(params[:page]-1)*params[:limit]..params[:page]*params[:limit]-1]
        @reports = raw.map{|r| Distributor.find(r['id']).user.default_decorated_attributes.merge(r)}
        r = {
          "meta" => {
            :count => @search.count,
            :limit => params[:limit],
            :offset => (params[:page]-1)*params[:limit]
          },
          "reports" => @reports
        }
        generate_success_response(r)
      end

      desc 'sales tax by zip'
      params do
        optional :limit, :type => Integer, :default => 25
        optional :page, :type => Integer, :default => 1
      end
      get 'reports/sales_tax' do
        @reports = Report.sales_tax(params)
        reports  = sales_tax_uniq_record(@reports)
        @summary = {
            "total" => reports.map{|a| a["tax_sum"].to_f }.sum.round(2),
            'order_total' =>reports.map{|a| a['order_total'].to_f}.sum.round(2),
            'shipping_total' =>reports.map{|a| a['shipping_sum'].to_f}.sum.round(2),
            'item_total'     =>reports.map{|a| a['order_itemtotal'].to_f}.sum.round(2),
        }
        r = {
            "meta" => {
                :count => reports.count,
                :limit => params[:limit],
                :offset => (params[:page]-1)*params[:limit]
            },
            "reports" => reports[(params[:page]-1)*params[:limit]..params[:page]*params[:limit]-1],
            "summary" => @summary
        }
        generate_success_response(r)
      end

      desc "monthly unilevel"
      params do
        optional :limit, :type => Integer, :default => 25
        optional :page, :type => Integer, :default => 1
      end
      get 'reports/monthly_unilevel' do
        @search = Report.monthly_unilevel(params)
        @reports = @search[(params[:page]-1)*params[:limit]..params[:page]*params[:limit]-1]

        @reports.each do |report|
          if report['order_info'].present?
            orders = report['order_info'].split(':')
            report["orders"] = orders.count
            report["qv"] = orders.map{|oo| oo.split(',')[1].to_f}.sum.round(2)
            report["uv"] = orders.map{|oo| oo.split(',')[4].to_f}.sum.round(2)
          else
            report["orders"] = 0
            report["qv"] = 0
            report["uv"] = 0
          end
        end

        r = {
          "meta" => {
            :count => @search.count,
            :limit => params[:limit],
            :offset => (params[:page]-1)*params[:limit]
          },
          "reports" => @reports
        }
        generate_success_response(r)
      end

      desc "buying bonus"
      params do
        requires :start_date
        requires :end_date
        optional :limit, :type => Integer, :default => 25
        optional :page, :type => Integer, :default => 1
        optional :country, :type => String, :default => 'All'
      end
      get 'reports/buying_bonus' do
        start_date = Date.parse(params[:start_date])
        end_date = Date.parse(params[:end_date]) + 1.day
        country = params['country'].presence
        if country
          orders = OrdersCoupon
            .joins(:order)
            .joins('LEFT JOIN addresses ON addresses.id = orders.ship_address_id')
            .joins('LEFT JOIN countries ON addresses.country_id = countries.id')
            .where("orders.completed_at" => start_date..end_date)
            .where("orders.state" => "complete")
            .where("orders.payment_state" => ["paid", "credit_owed"])
            .where("countries.iso_name like \'#{country}\'")
        else
          orders = OrdersCoupon
            .joins(:order)
            .joins('LEFT JOIN addresses ON addresses.id = orders.ship_address_id')
            .joins('LEFT JOIN countries ON addresses.country_id = countries.id')
            .where("orders.state" => "complete")
            .where("orders.payment_state" => ["paid", "credit_owed"])
            .where("orders.completed_at between '#{start_date}' and '#{end_date}'")
        end
        reports = []
        count = 0
        orders.each do |order|
          if count >= (params[:page]-1)*params[:limit] && count < params[:page]*params[:limit]
            reports += order.records
          end
          count += order.amount
        end
        r = {
          "meta" => {
            :count => count,
            :limit => params[:limit],
            :offset => (params[:page]-1)*params[:limit]
          },
          "reports" => reports
        }
        generate_success_response(r)
      end

      desc 'advisor sponsorship count'
      params do
        optional :limit, :type => Integer, :default => 25
        optional :page, :type => Integer, :default => 1
      end
      get 'reports/sponsor_count' do
        @search = Report.sponsor_count(params)
        @reports = @search[(params[:page]-1)*params[:limit]..params[:page]*params[:limit]-1]
        r = {
          "meta" => {
            :count => @search.count,
            :limit => params[:limit],
            :offset => (params[:page]-1)*params[:limit]
          },
          "reports" => @reports
        }
        generate_success_response(r)
      end

      desc 'promotion'
      params do
        optional :limit, :type => Integer, :default => 25
        optional :page, :type => Integer, :default => 1
      end
      get 'reports/promotion' do
        @search = Report.promotion(params)
        @reports = @search[(params[:page]-1)*params[:limit]..params[:page]*params[:limit]-1]
        r = {
          "meta" => {
            :count => @search.count,
            :limit => params[:limit],
            :offset => (params[:page]-1)*params[:limit]
          },
          "reports" => @reports
        }
        generate_success_response(r)
      end

      desc 'inventory'
      params do
        optional :limit, :type => Integer, :default => 25
        optional :page, :type => Integer, :default => 1
      end
      get 'reports/inventory' do
        @search = Report.inventory(params)
        @reports = @search[(params[:page]-1)*params[:limit]..params[:page]*params[:limit]-1]
        r = {
          "meta" => {
            :count => @search.count,
            :limit => params[:limit],
            :offset => (params[:page]-1)*params[:limit]
          },
          "reports" => @reports
        }
        generate_success_response(r)
      end

      desc 'inventory history'
      params do
        requires :variant_id, :type => Integer
        optional :limit, :type => Integer, :default => 25
        optional :page, :type => Integer, :default => 1
      end
      get 'reports/inventory_history' do
        @search = Report.inventory_history(params)
        @reports = @search[(params[:page]-1)*params[:limit]..params[:page]*params[:limit]-1]
        r = {
          "meta" => {
            :count => @search.count,
            :limit => params[:limit],
            :offset => (params[:page]-1)*params[:limit]
          },
          "reports" => @reports
        }
        generate_success_response(r)
      end

      desc 'volumes'
      params do
        optional :limit, :type => Integer, :default => 25
        optional :page, :type => Integer, :default => 1
        optional :order, :type => String, :default => 'Personal Volume'
      end
      get 'reports/volumes' do
        @search = Report.volumes(params)
        @reports = @search[(params[:page]-1)*params[:limit]..params[:page]*params[:limit]-1]
        r = {
          "meta" => {
            :count => @search.count,
            :limit => params[:limit],
            :offset => (params[:page]-1)*params[:limit]
          },
          "reports" => @reports
        }
        generate_success_response(r)
      end

      desc 'Top Recruiter'
      params do
        optional :limit,  :type => Integer, :default => 25
        optional :offset, :type => Integer, :default => 0
        optional :all,    :type => Boolean, :default => false
      end
      get 'reports/top_recruiter' do
        result = top_recruiter(params)
        count  = result.count
        if params[:all]
          users = result
        else
          users = result[params[:offset]..params[:offset]+params[:limit]-1]
        end
        r = {
            'meta' => {
                :limit   => params[:limit],
                :offset  => params[:offset],
                :count   => count
            },
            'users' => users
        }
        generate_success_response(r)
      end

    end #namespace admin
  end
end
