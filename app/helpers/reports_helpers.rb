module ReportsHelpers

  #@param[start_date] string  eg: '2014-05-05'
  #@return[products] array[hash]
  def top_ten_products(opts = {})
    if !opts[:start_date].present? || !opts[:end_date].present?
      return []
    end
    type        = opts[:type] || 'price'
    sort1 = (type == 'price') ? 'total' : 'quant'
    sort2 = (type == 'price') ? 'quant' : 'total'
    start_date = Date.parse(opts[:start_date])
    end_date   = Date.parse(opts[:end_date]) + 1.day
    country    = opts[:country] == 'All' ? '%%' : opts[:country]
    line_items = LineItem.select("line_items.variant_id, sum(line_items.quantity * line_items.retail_price) as total, sum(line_items.quantity) as quant, currencies.iso_code")
                         .joins(:order, "LEFT JOIN currencies ON currencies.id = orders.currency_id")
                         .joins("LEFT JOIN addresses ON addresses.id = orders.ship_address_id")
                         .joins("LEFT JOIN countries ON countries.id = addresses.country_id")
                         .where('orders.state = ?', 'complete')
                         .where('countries.iso_name like ?', country)
                         .where("orders.completed_at" => start_date..end_date)
                         .group('line_items.variant_id, currencies.iso_code')
                         .order("#{sort1} desc, #{sort2} desc")
    products = []
    line_items.each do |line_item|
      if line_item.product
        products << line_item.product.attributes.merge({
          currency:   line_item.iso_code,
          sku:        line_item.variant.try(:sku),
          cost:       line_item.variant.try(:cost_price),
          total:      ('%.2f' % line_item.total.to_f),
          quantity:   line_item.quant
        })
      end
    end
    products
  rescue
    []
  end


  def sales_report(params)
    # if !params[:start_date].present? || !params[:end_date].present?
    #   return []
    # end
    # first = Date.parse(params[:start_date])
    # last = Date.parse(params[:end_date]) + 1
    # country    = params[:country].present? ? params[:country] : '%'
    # orders = Order.joins("LEFT JOIN addresses ON addresses.id = orders.ship_address_id")
    #               .joins("LEFT JOIN countries ON countries.id = addresses.country_id")
    #               .where(order_date: first..last, state: 'complete')
    #               .where(payment_state: ['paid', 'credit_owed'])
    #               .where('countries.iso_name like ?', country)
    #               .where(params[:state_id].to_i > 0 ? "addresses.state_id = #{params[:state_id].to_i}" : nil)
    # orders.map { |o| o.attributes.update(order_attributes(o)) }

    if params[:start_date].nil?
      return []
    end
    first = Date.parse(params[:start_date]) rescue nil
    last  = (Date.parse(params[:end_date]) + 1) rescue nil
    #country    = params[:country].present? ? params[:country] : '%'
    orders = Order.select('orders.id, orders.user_id, orders.number, orders.order_date, orders.item_total, orders.total,
                           orders.state, orders.adjustment_total, orders.credit_total, orders.completed_at,
                           orders.bill_address_id, orders.ship_address_id, orders.payment_total, orders.shipping_method_id, orders.shipment_state, orders.payment_state, orders.email, orders.currency_id,
                           ship_address.city as shipto_city, ship_states.name as shipto_state, ship_country.name as shipto_country,
                           d.id as dist_id, (home_address.lastname || \',\' || home_address.firstname) as dist_name, r.name as dist_role, home_address.city as dist_city,
                           home_states.name as dist_state, home_country.name as dist_country, currencies.iso_code as currency_iso_code,
                           shipments.cost as freight, adjustments.amount as sales_tax,
                           d.personal_sponsor_distributor_id as sponsor_id, d.dualteam_sponsor_distributor_id as b_sponsor_id')
                  .joins('inner join users on orders.user_id = users.id')
                  .joins('inner join distributors as d on d.user_id = users.id')
                  .joins('inner join roles_users as ru on ru.user_id = users.id')
                  .joins('inner join roles as r on r.id = ru.role_id')
                  .joins('LEFT JOIN addresses as ship_address ON ship_address.id = orders.ship_address_id')
                  .joins('LEFT JOIN states as ship_states ON ship_states.id = ship_address.state_id')
                  .joins('LEFT JOIN countries as ship_country ON ship_country.id = ship_address.country_id')
                  .joins('LEFT JOIN users_home_addresses as uha ON uha.user_id = users.id')
                  .joins('LEFT JOIN addresses as home_address ON home_address.id = uha.address_id')
                  .joins('LEFT JOIN states as home_states ON home_states.id = home_address.state_id')
                  .joins('LEFT JOIN countries as home_country ON home_country.id = home_address.country_id')
                  .joins('LEFT JOIN currencies ON currencies.id = orders.currency_id')
                  .joins('LEFT JOIN (select shipments.order_id order_id, sum(shipments.cost) as cost from shipments GROUP BY order_id) as shipments ON shipments.order_id = orders.id')
                  .joins('LEFT JOIN (select order_id, sum(amount) as amount from adjustments where label = \'sales_tax\' group by order_id) as adjustments ON adjustments.order_id = orders.id')
                  .joins('inner join line_items on orders.id = line_items.order_id')
                  .joins('inner join variants on variants.id = line_items.variant_id')
                  .joins('left join products on products.id = variants.product_id')
                  .where(params[:distributor_id].present? ? ['d.id = ?', params[:distributor_id].to_i] : nil)
                  .where(params[:number].present? ? ['orders.number ilike ?', "%#{params[:number]}%"] : nil)
                  .where(params[:product_name].present? ? ['products.name ilike ?', "%#{params[:product_name]}%"] : nil)
                  .where(params[:first_name].present? ? ['home_address.firstname = ?', params[:first_name]] : nil)
                  .where(params[:last_name].present? ? ['home_address.lastname = ?', params[:last_name]] : nil)
                  .where(first ? ['orders.order_date >= ?', first] : nil)
                  .where(last ?  ['orders.order_date < ?', last] : nil)
                  .where(params[:country].present? ? ['ship_country.iso = ?', params[:country]] : nil)
                  .where(params[:state_id].to_i > 0 ? "ship_address.state_id = #{params[:state_id].to_i}" : nil)
                  .where(params[:sku].present? ? ['variants.sku ilike ?', "%#{params[:sku]}%"] : nil)
                  .where(state: 'complete')
                  .where("uha.is_default = 't'")
                  .where(payment_state: ['paid', 'credit_owed'])
                  .group('orders.id, orders.user_id, orders.number, orders.order_date, orders.item_total, orders.total,
                          orders.state, orders.adjustment_total, orders.credit_total, orders.completed_at,
                          orders.bill_address_id, orders.ship_address_id, orders.payment_total, orders.shipping_method_id, orders.shipment_state, orders.payment_state, orders.email, orders.currency_id,
                          shipto_city, shipto_state, shipto_country, dist_id, dist_name, dist_role, dist_city, dist_state, dist_country, currency_iso_code, freight, sales_tax, sponsor_id, b_sponsor_id')
                  .order('orders.order_date desc')
    orders.map { |o| o.attributes.update(order_format_attr(o)) }
  end

  def order_format_attr(order)
    {
        order_date:     order.order_date.try(:strftime, '%Y-%m-%d'),
        completed_at:   order.completed_at.try(:strftime, '%Y-%m-%d'),
        shipto_city:    order.shipto_city,
        shipto_state:   order.shipto_state,
        shipto_country: order.shipto_country,
        dist_id:        order.dist_id,
        dist_name:      order.dist_name,
        dist_role:      order.dist_role,
        dist_city:      order.dist_city,
        dist_state:     order.dist_state,
        dist_country:   order.dist_country,
        currency:       order.currency_iso_code,
        freight:        order.freight,
        sales_tax:      order.sales_tax,
        sponsor_id:     order.sponsor_id,
        b_sponsor_id:   order.b_sponsor_id
    }
  end

  def order_attributes(order)
    {
      order_date:     order.order_date.try(:strftime, '%Y-%m-%d'),
      completed_at:   order.completed_at.try(:strftime, '%Y-%m-%d'),
      shipto_city:    order.ship_address.try(:city),
      shipto_state:   order.ship_address.try(:state).try(:name),
      shipto_country: order.ship_address.try(:country).try(:name),
      dist_id:        order.user.try(:distributor).try(:id),
      dist_name:      order.user.try(:name),
      dist_role:      order.user.try(:roles).first.try(:name),
      dist_city:      order.user.try(:default_home_address).try(:city),
      dist_state:     order.user.try(:default_home_address).try(:state).try(:name),
      dist_country:   order.user.try(:default_home_address).try(:country).try(:name),
      currency:       order.currency.try(:iso_code),
      freight:        order.shipments.first.try(:cost),
      sales_tax:      order.adjustments.map{|a| a.label == 'sales_tax' ? a.amount : nil}.compact[0],
      sponsor_id:     order.user.try(:distributor).try(:personal_sponsor_distributor_id),
      b_sponsor_id:   order.user.try(:distributor).try(:dualteam_sponsor_distributor_id)
    }
  end

  def sales_tax_uniq_record(active_obj)
    result  = []
    obj_arr = active_obj.to_ary

    obj_arr.each do |oa|
      exist = result.select { |r| r['order_number'] == oa['order_number'] }
      result.push(oa) if exist.length == 0
    end
    result
  end

  def top_recruiter(params)
    where = ''
    if params[:role_code].present?
      role_id = Role.find_by(role_code: params[:role_code]).try(:id)
      if role_id
        where += "and ru.role_id = #{role_id} "
        if params[:role_code] == 'D'
          where += "and d.next_renewal_date >= '#{Time.now.to_date}'"
        end
      end
    end
    where += "and u.entry_date >= '#{params[:startDate]}' " if params[:startDate].present?
    where += "and u.entry_date < '#{params[:endDate].to_date + 1}' "    if params[:endDate].present?
    where += "and d.personal_sponsor_distributor_id = #{params[:distributor_id].to_i}" if params[:distributor_id].present?

    order = ''
    fields = %w[distributor_id user_name role_code d_count r_count count]
    if fields.include?(params[:sort])
      _oby  = params[:direction] == 'asc' ? 'asc' : 'desc'
      order += "#{params[:sort]} #{_oby}"
    else
      order = 'count desc'
    end

    _sql = "select aa.personal_sponsor_distributor_id as distributor_id, add.firstname || ' ' || add.lastname as user_name, aa.d_count, aa.r_count, aa.count as count
            from distributors d inner join users u on d.user_id = u.id
            inner join (
              select T.personal_sponsor_distributor_id,max(case role_code when 'D' then count else 0 end) d_count, max(case role_code when 'R' then count else 0 end) r_count, sum(count) count
              from (select d.personal_sponsor_distributor_id, count(d.id) as count, r.role_code from distributors d, users u, roles_users ru, roles r
                    where ru.user_id = u.id and d.user_id = u.id and ru.role_id = r.id and u.status_id = 1 #{where} group by d.personal_sponsor_distributor_id, role_code) T
              group by T.personal_sponsor_distributor_id
            ) as aa on d.id = aa.personal_sponsor_distributor_id
            inner join users_home_addresses as u_home_add on u_home_add.user_id = u.id
            inner join addresses as add on add.id = u_home_add.address_id
            where u_home_add.active = true and u_home_add.is_default = true order by #{order}"
    ActiveRecord::Base.connection.select_all(_sql)
  end

end
