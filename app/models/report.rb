class Report < ActiveRecord::Base
  def self.enrollment(query_params)
      query_params[:start_date] = Time.now.strftime("%Y-%m-%d") if query_params[:start_date].blank?
      query_params[:end_date] = Time.now.strftime("%Y-%m-%d")   if query_params[:end_date].blank?
      query_params[:end_date] = (query_params[:end_date].to_date + 1).strftime("%Y-%m-%d")
      if query_params[:country].present?
        country = " c.id = #{query_params[:country]} and "
      else
        country = ' '
      end
      if query_params[:state].present?
        state = " st.id = #{query_params[:state]} and "
      else
        state = ' '
      end
      if query_params[:role].present?
        role = " r.name = \'#{query_params[:role]}\' and "
      else
        role = ' '
      end
      if query_params[:active] == "true"
        status_query = " and ss.name = \'Active\' "
      else
        status_query = ' '
      end

      sqlcmd = "SELECT distinct d.id distributor_id,
                  u.id user_id,
                  ad.firstname,
                  ad.lastname,
                  ad.firstname || ' ' || ad.lastname as primary_name,
                  ad.joint_firstname || ' ' || ad.joint_lastname as coapp_name,
                  d.date_of_birth,
                  ad.city,
                  ad.address1,
                  ad.zipcode,
                  ad.phone,
                  u.email email,
                  st.name state,
                  c.iso country,
                  c.name country_name,
                  to_char(u.entry_date, 'YYYY-MM-DD') as enrollment_date,
                  d.personal_sponsor_distributor_id as sponsor_id,
                  d.dualteam_sponsor_distributor_id as binary_sponsor_id,
                  d.dualteam_current_position as binary_position,
                  r.name profile,
                  ss.name status_name,
                  add_sponsor.lastname || ', ' || add_sponsor.firstname as sponsor_name
                FROM distributors d,
                  users_home_addresses u_home_ad,
                  roles r,
                  roles_users ru,
                  addresses ad
                  left join countries c on c.id = ad.country_id
                  left join states st on st.id = ad.state_id,
                  users u,
                  statuses ss,
                  distributors d_sponsor,
                  users u_sponsor,
                  users_home_addresses uha,
                  addresses add_sponsor
                WHERE u.entry_date >= '#{query_params[:start_date]}' and u.entry_date < '#{query_params[:end_date]}' and
                  u_home_ad.user_id = u.id and
                  u_home_ad.is_default = true and
                  u_home_ad.active = true and
                  u_home_ad.address_id = ad.id and
                  #{country}
                  #{state}
                  #{role}
                  d.user_id = u.id and
                  ru.user_id = u.id and
                  ru.role_id = r.id and
                  ad.country_id = c.id and
                  ad.state_id = st.id and
                  ss.id = u.status_id and
                  d.personal_sponsor_distributor_id = d_sponsor.id and
                  d_sponsor.user_id = u_sponsor.id and
                  u_sponsor.id = uha.user_id and
                  uha.address_id = add_sponsor.id and
                  uha.active = true and
                  uha.is_default = true
                  #{status_query}
                ORDER BY enrollment_date"
      ActiveRecord::Base.connection.select_all(sanitize_sql(sqlcmd))
  end

  def self.sales_by_product(query_params)
      query_params[:start_date] = Time.now.strftime("%Y-%m-%d") if query_params[:start_date].blank?
      query_params[:end_date] = Time.now.strftime("%Y-%m-%d")   if query_params[:end_date].blank?
      query_params[:end_date] = (query_params[:end_date].to_date + 1).strftime("%Y-%m-%d")
      query_params[:country] = '%%' if query_params[:country].blank? or query_params[:country] == 'All'
      name_search = query_params[:product] ? "and LOWER(p.name) like LOWER(\'%#{query_params[:product]}%\')" : ""

      sqlcmd = "SELECT v.sku item_code,
                       p.name,
                       to_char(o.order_date, 'YYYY-MM-DD') as order_date,
                       o.state order_status,
                       o.id order_id,
                       o.number order_number,
                       cn.iso_code currency,
                       sum(li.quantity) as quantity,
                       sum(li.quantity * li.price) as price_total,
                       distributors.id as distributor_id,
                       (array_agg(ad.firstname || ' ' || ad.lastname))[1] as distributor_name
                  FROM orders o,
                       countries c,
                       addresses ad,
                       line_items li,
                       currencies cn,
                       variants v,
                       products p,
                       distributors
                 WHERE o.id = li.order_id and
                       o.state in ('cancelled', 'complete', 'awaiting_return', 'returned') and
                       o.payment_state in ('paid','credit_owed') and
                       cn.id = o.currency_id and
                       p.id = v.product_id and
                       li.variant_id = v.id and
                       o.order_date >= '#{query_params[:start_date]}' and o.order_date < '#{query_params[:end_date]}' and
                       ad.country_id = c.id and
                       ad.id = o.ship_address_id and
                       o.user_id = distributors.user_id and
                       c.iso_name like \'#{query_params[:country]}\'
                       #{name_search}
              GROUP BY v.sku, p.name, o.order_date, cn.iso_code, o.state, o.id, o.number, distributors.id
              ORDER BY o.order_date, quantity desc, o.state"
      ActiveRecord::Base.connection.select_all(sanitize_sql(sqlcmd))
  end

  def self.shipping_charge(query_params)
      query_params[:start_date] = Time.now.strftime("%Y-%m-%d") if query_params[:start_date].blank?
      query_params[:end_date] = Time.now.strftime("%Y-%m-%d")   if query_params[:end_date].blank?
      query_params[:end_date] = (query_params[:end_date].to_date + 1).strftime("%Y-%m-%d")

      sqlcmd = "SELECT cn.name,
                       sum(adj.amount) as shipping_charge,
                       cu.iso_code as currency
                  FROM orders o,
                       addresses ad,
                       adjustments adj,
                       countries cn, currencies cu
                 WHERE o.id = adj.order_id and
                       o.ship_address_id = ad.id and
                       ad.country_id = cn.id and
                       adj.source_type = 'Shipment' and
                       cu.id = o.currency_id and
                       o.state = 'complete' and
                       o.payment_state in ('paid','credit_owed') and
                       o.order_date >= '#{query_params[:start_date]}' and o.order_date < '#{query_params[:end_date]}'
              GROUP BY cn.name, cu.iso_code"

      ActiveRecord::Base.connection.select_all(sanitize_sql(sqlcmd))
  end

  def self.sales_items(query_params)
      query_params[:start_date] = Time.now.strftime("%Y-%m-%d") if query_params[:start_date].blank?
      query_params[:end_date] = Time.now.strftime("%Y-%m-%d")   if query_params[:end_date].blank?
      query_params[:end_date] = (query_params[:end_date].to_date + 1).strftime("%Y-%m-%d")
      query_params[:country] = '%%' if query_params[:country].blank? or query_params[:country] == 'All'
      name_search = query_params[:product] ? "and LOWER(products.name) like LOWER(\'%#{query_params[:product]}%\')" : ""

      sqlcmd = "SELECT orders.id as order_id,
                       orders.number as order_number,
                       to_char(orders.order_date, 'YYYY-MM-DD') as order_date,
                       to_char(cv.state_date, 'YYYY-MM-DD') as payment_date,
                       shipstate.name AS ship_state,
                       shipcountry.iso AS ship_country,
                       line_items.line_no as order_line_no,
                       variants.sku as sku,
                       products.name as product_name,
                       cn.iso_code currency,
                       line_items.quantity as quantity,
                       line_items.price as unit_price,
						           distributors.id as distributor_id,
						           shipaddress.firstname || ' ' || shipaddress.lastname as distributor_name
                  FROM data_management.commission_volume cv,
                       line_items,
                       products,
                       variants,
                       orders,
                       currencies cn,
                       distributors,
                       addresses shipaddress
                       LEFT JOIN states shipstate ON (shipstate.id = shipaddress.state_id)
                       LEFT JOIN countries shipcountry ON (shipcountry.id = shipaddress.country_id)
                 WHERE shipcountry.iso_name like \'#{query_params[:country]}\' and
                       cv.state_date >= '#{query_params[:start_date]}' and cv.state_date < '#{query_params[:end_date]}' and
                       orders.order_date >= '#{query_params[:start_date]}' and orders.order_date < '#{query_params[:end_date]}' and
                       cv.order_commission_state = 'forward'
                       and cv.order_id = orders.id and
                       cn.id = orders.currency_id and
                       orders.ship_address_id = shipaddress.id and
                       orders.id = line_items.order_id and
                       orders.user_id = distributors.user_id and
                       line_items.variant_id = variants.id and
                       variants.product_id = products.id and
                       orders.state in ('complete', 'awaiting_return', 'returned')
                       #{name_search}
              ORDER BY orders.order_date"

      ActiveRecord::Base.connection.select_all(sanitize_sql(sqlcmd))
  end

  def self.volume_6m(query_params)
      query_params[:start_date] = Time.now.strftime("%Y-%m-%d") if query_params[:start_date].blank?
      query_params[:end_date] = Time.now.strftime("%Y-%m-%d")   if query_params[:end_date].blank?
      query_params[:end_date] = (query_params[:end_date].to_date + 1).strftime("%Y-%m-%d")
      if query_params[:country].blank? or query_params[:country] == 'All'
        country = ' '
      else
        country = " and c.iso_name = \'#{query_params[:country]}\' "
      end
      order = 'pv'
      case query_params[:order]
      when 'Direct Team Volume'
        order = 'dtv'
      when 'Team Volume'
        order = 'tv'
      else
        order = 'pv'
      end
      sqlcmd = "SELECT d1.id,
                       ad.firstname || ' ' || ad.lastname as primary_name,
                       r.name role_name,
                       to_char(u.entry_date, 'yyyy-mm-dd') enrollment_date,
                       d1.personal_sponsor_distributor_id sponsor_id,
                       sum(cv1.pvq) pv,
                       array(select distributor_id from get_ul_children_on_path(1, d1.id)) arr
                  FROM distributors d1
             LEFT JOIN users u ON u.id = d1.user_id
             LEFT JOIN users_home_addresses uha ON uha.user_id = d1.user_id and uha.is_default = true and uha.active = true
             LEFT JOIN addresses ad ON uha.address_id = ad.id
             LEFT JOIN countries c ON c.id = ad.country_id
             LEFT JOIN data_management.commission_volume cv1 ON cv1.user_id = u.id
             LEFT JOIN roles_users ru ON ru.user_id = d1.user_id
             LEFT JOIN roles r ON ru.role_id = r.id
                 WHERE cv1.state_date >= \'#{query_params[:start_date]}\'
                   AND cv1.state_date < \'#{query_params[:end_date]}\'
                   AND cv1.order_commission_state = 'forward'
                       #{country}
              GROUP BY d1.id, primary_name, r.name, sponsor_id, to_char(u.entry_date, 'yyyy-mm-dd')
              ORDER BY pv desc"
      res = ActiveRecord::Base.connection.select_all(sanitize_sql(sqlcmd)).to_hash
      team = Hash.new 0
      direct = Hash.new 0
      res.each do |r|
        r['arr'] = r['arr'].scan(/\d+/)
        r['pv'] = r['pv'].to_f
        direct[r['sponsor_id']] += r['pv']
        r['arr'].each{|a| team[a] += r['pv'] }
      end
      res.each do |r|
        r['dtv'] = direct[r['id']]
        r['tv'] = team[r['id']]
        r.delete('arr')
      end
      res.sort_by{|hash| -hash["#{order}"]}
  end

  def self.sales_by_person(query_params)
      query_params[:start_date] = Time.now.strftime("%Y-%m-%d") if query_params[:start_date].blank?
      query_params[:end_date] = Time.now.strftime("%Y-%m-%d")   if query_params[:end_date].blank?
      query_params[:end_date] = (query_params[:end_date].to_date + 1).strftime("%Y-%m-%d")

      sql = "
        select array(select distributor_id from get_dt_children_on_path(get_top_dt(sub.id), sub.id)) arr, id
         from (select distinct d.id
                 from data_management.commission_volume cv,
                      distributors d,
                      roles_users ru
                where d.user_id = cv.user_id
                  and d.user_id = ru.user_id
                  and cv.state_date >= '#{query_params[:start_date]}'
                  and cv.state_date < '#{query_params[:end_date]}'
                  and cv.order_commission_state = 'forward'
                  and cv.pvq > 0
                  and ru.role_id in (2, 5)
               ) as sub "
      res = ActiveRecord::Base.connection.select_all(sanitize_sql(sql)).to_hash
      res.each{|r| r['arr'] = r['arr'].scan(/\d+/)}
      res.each{|r| r['arr'].delete(r['id'])}
      count = Hash.new 0
      res.each{|r| r['arr'].each {|a| count[a] += 1}}
      count.map{|k,v| {'id'=>k, 'amount'=>v}}.sort_by{|c| -c['amount']}
  end

  def self.sales_tax(query_params)
      query_params[:start_date] = Time.now.strftime("%Y-%m-%d") if query_params[:start_date].blank?
      query_params[:end_date] = Time.now.strftime("%Y-%m-%d")   if query_params[:end_date].blank?
      query_params[:end_date] = (query_params[:end_date].to_date + 1).strftime("%Y-%m-%d")
      country_sql = if query_params[:country_id].to_i > 0
                      "c.id = #{query_params[:country_id]} and "
                    else
                      country = Country.find_by(iso: 'US')
                      "c.id = #{country.id} and "
                    end
      state_sql = query_params[:state_id].to_i > 0 ? "s.id = #{query_params[:state_id]} and " : ''

      sqlcmd = "select a1.state,a1.city,a1.zipcode,a1.tax_sum,a2.shipping_sum,a1.currency,a1.country_iso,a1.state_abbr,a1.order_number, a1.order_total, a1.order_itemtotal from
                  (SELECT s.name state,
                       lower(add.city) as city,
                       add.zipcode,
                       sum(adj.amount) as tax_sum,
                       cur.iso_code currency,
                       c.iso country_iso,
                       s.abbr state_abbr,
                       string_agg(o.number, ',') as order_number,
                       sum(o.total) as order_total,
                       sum(o.item_total) as order_itemtotal
                  FROM orders o,
                       addresses add,
                       adjustments adj,
                       countries c,
                       states s,
                       currencies cur
                 WHERE #{country_sql}
                       #{state_sql}
                       o.id = adj.order_id and
                       o.ship_address_id = add.id and
                       add.country_id = c.id and
                       add.state_id = s.id and
                       adj.label = 'sales_tax' and
                       cur.id = o.currency_id and
                       o.state = 'complete' and
                       o.payment_state in ('paid','credit_owed') and
                       o.order_date >= '#{query_params[:start_date]}' and o.order_date < '#{query_params[:end_date]}'
                 GROUP BY add.zipcode, s.name, cur.iso_code, lower(add.city), c.iso, s.abbr
                 HAVING sum(adj.amount) > 0.0) as a1 full outer join (
                  SELECT s.name state,
                       lower(add.city) as city,
                       add.zipcode,
                       sum(adj.amount) as shipping_sum,
                       cur.iso_code currency,
                       c.iso country_iso,
                       s.abbr state_abbr,
                       string_agg(o.number, ',') as order_number,
                       sum(o.total) as order_total,
                       sum(o.item_total) as order_itemtotal
                  FROM orders o,
                       addresses add,
                       adjustments adj,
                       countries c,
                       states s,
                       currencies cur
                  WHERE #{country_sql}
                       #{state_sql}
                       o.id = adj.order_id and
                       o.ship_address_id = add.id and
                       add.country_id = c.id and
                       add.state_id = s.id and
                       (adj.label = 'Shipping' or adj.originator_type = 'ShippingMethod') and
                       cur.id = o.currency_id and
                       o.state = 'complete' and
                       o.payment_state in ('paid','credit_owed') and
                       o.order_date >= '#{query_params[:start_date]}' and o.order_date < '#{query_params[:end_date]}'
                  GROUP BY add.zipcode, s.name, cur.iso_code, lower(add.city), c.iso, s.abbr
                  HAVING sum(adj.amount) > 0.0) as a2 on a1.zipcode = a2.zipcode and a1.city = a2.city
               ORDER BY a1.state"

      ActiveRecord::Base.connection.select_all(sanitize_sql(sqlcmd))
  end

  def self.sponsor_count(params)
    params[:start_date] = Time.now.strftime("%Y-%m-%d") if params[:start_date].blank?
    params[:end_date] = Time.now.strftime("%Y-%m-%d")   if params[:end_date].blank?
    params[:end_date] = (params[:end_date].to_date + 1).strftime("%Y-%m-%d")
    if params[:country].blank? or params[:country] == 'All'
      country = ' '
    else
      country = " and c.iso_name = \'#{params[:country]}\' "
    end
    sql = "select d1.id,
                  add.firstname || ' ' || add.lastname as name,
                  sum(CASE WHEN r2.role_code = 'D' THEN 1 ELSE 0 END) advisors,
                  sum(CASE WHEN r2.role_code = 'R' THEN 1 ELSE 0 END) customers
             from distributors d1
        left join distributors d2 on d1.id = d2.personal_sponsor_distributor_id
        left join users u2 on d2.user_id = u2.id
        left join roles_users ru2 on ru2.user_id = u2.id
        left join roles r2 on r2.id = ru2.role_id
        left join users_home_addresses uha on uha.user_id = d1.user_id and uha.is_default = true and uha.active = true
        left join addresses add on add.id = uha.address_id
        left join countries c on c.id = add.country_id
            where u2.entry_date >= \'#{params[:start_date]}\'
              and u2.entry_date < \'#{params[:end_date]}\'
                  #{country}
         group by d1.id, add.firstname || ' ' || add.lastname
         order by advisors desc"
    ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
  end

  def self.promotion(params)
    if params[:date].blank?
      search_date = Time.now.strftime("%Y-%m-%d")
    else
      search_date = "#{params[:date]}"
    end
    date = search_date.to_date.strftime("%Y%m01")
    if params[:country].blank? or params[:country] == 'All'
      country = ' '
    else
      country = " and c.iso_name = \'#{params[:country]}\' "
    end
    sql = "select b.first_name,
                  b.last_name,
                  d.id,
                  cr1.name prev,
                  cr2.name curr
             from bonus.bonusm#{date} b
        left join distributors d on d.id = b.id
        left join users_home_addresses uha on uha.user_id = d.user_id and uha.is_default = true and uha.active = true
        left join addresses add on add.id = uha.address_id
        left join countries c on c.id = add.country_id
        left join client_ranks cr1 on cr1.rank_identity = b.prev_rank
        left join client_ranks cr2 on cr2.rank_identity = b.lifetime_rank
            where b.prev_rank < b.lifetime_rank
              and b.prev_rank != 0
                 #{country}
         order by b.first_name asc, b.last_name asc"
    ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
  end

  def self.inventory(params)
    params[:start_date] = Time.now.strftime("%Y-%m-%d") if params[:start_date].blank?
    params[:end_date] = Time.now.strftime("%Y-%m-%d")   if params[:end_date].blank?
    params[:end_date] = (params[:end_date].to_date + 1).strftime("%Y-%m-%d")
    name_search = params[:product] ? "where LOWER(p.name) like LOWER(\'%#{params[:product]}%\')" : ""
    if params[:country].blank? or params[:country] == 'All'
      country = ' '
    else
      country = " and c.iso_name = \'#{params[:country]}\' "
    end
    table_check = "select * from pg_tables where tablename = 'variant_stock_records'"
    create_table = "create table variant_stock_records (id serial primary key, variant_id int not null, new_amount int not null, load_amount int not null, created_at timestamp with time zone not null)"
    sql = "select p.name,
                  p.id product_id,
                  v.sku,
                  v.id variant_id,
                  vsr.new_amount,
                  vsr.created_at,
                  sum(li.quantity)
             from products p
       inner join variants v on p.id = v.product_id and v.deleted_at is null
        left join variant_stock_records vsr
               on vsr.variant_id = v.id
              and vsr.id = (select max(id) from variant_stock_records where variant_id = v.id)
        left join (line_items li
                   right join orders o
                   on li.order_id = o.id
                   right join addresses add on o.ship_address_id = add.id
                   right join countries c on add.country_id = c.id #{country}
                  )
               on li.variant_id = v.id
              and o.order_date >= vsr.created_at
              and o.state = 'complete'
              and o.payment_state in ('paid','credit_owed')
                  #{name_search}
         group by p.name, v.sku, p.id, v.id, vsr.new_amount, vsr.created_at
         order by coalesce(vsr.new_amount, 0) - coalesce(sum(li.quantity), 0), p.id"
    res = ActiveRecord::Base.connection.select_all(sanitize_sql(table_check))
    if res.count == 0
      ActiveRecord::Base.connection.execute(sanitize_sql(create_table))
    end
    ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
  end

  def self.update_amount(params)
    sql = "insert into variant_stock_records (variant_id, new_amount, load_amount, created_at)
           values (#{params[:id]}, #{params[:new]}, #{params[:load]}, now())"
    ActiveRecord::Base.connection.execute(sanitize_sql(sql))
  end

  def self.inventory_history(params)
    sql = "
           select *
             from variant_stock_records
            where variant_id = #{params[:variant_id]}
         order by id
          "
    ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
  end

  def self.volumes(params)
    if params[:date].blank?
      search_date = Time.now.strftime("%Y-%m-%d")
    else
      search_date = "#{params[:date]}"
    end
    date = search_date.to_date.strftime("%Y%m01")
    if params[:country].blank? or params[:country] == 'All'
      country = ' '
    else
      country = " where c.iso_name = \'#{params[:country]}\' "
    end
    case params[:order]
    when 'Group Volume'
        order = 'gv'
    when 'Team Volume'
        order = 'tv'
    else
        order = 'pv'
    end
    sql = "select d.id, r.details
             from bonus.bonusm#{date}_ranks r
        left join distributors d on d.id = r.distributor_id
        left join users_home_addresses uha on uha.user_id = d.user_id and uha.is_default = true and uha.active = true
        left join addresses add on add.id = uha.address_id
        left join countries c on c.id = add.country_id
                 #{country}"
    res = ActiveRecord::Base.connection.select_all(sanitize_sql(sql)).to_hash
    res.each{|r| r['json'] = JSON.parse(r["details"]) }
    ult = []
    res.each do |r|
      a = {
        'name' => r['json']['name'],
        'id' => r['id'],
        'pv' => r['json']['personal-qualification-volume'],
        'dtv' => r['json']['direct-team-qualification-volume'],
        'itv' => r['json']['indirect-team-qualification-volume'],
        'tv' => r['json']['team-qualification-volume'],
        'gv' => r['json']['group-qualification-volume'],
        'av' => r['json']['autoship-volume']
      }
      ult << a if a['pv'].to_f + a['tv'].to_f + a['gv'].to_f > 0
    end
    ult.sort_by{|hash| -hash["#{order}"]}
  end

  def self.direct_deposit(params)
    if params[:date].blank?
      search_date = Time.now.strftime("%Y-%m-%d")
    else
      search_date = "#{params[:year]}#{params[:date]}"
    end
    date = search_date.to_date.strftime("%Y%m01")

    _where = nil
    _where = " and dbi.distributor_id = #{params[:distributor_id].to_i} " if params[:distributor_id].present? && params[:distributor_id].to_i > 0

    check = "select * from pg_tables where schemaname = 'bonus' and tablename = 'bonusm#{date}_manual_commissions'"
    create = "create table bonus.bonusm#{date}_manual_commissions (commission_type_id int not null, distributor_id int not null, commission numeric(18,2), overview text, details text, primary key(distributor_id, commission_type_id))"
    sql = "
           select dbi.bank_code,
                  dbi.bank_account_number,
                  sum(c1.commission),
                  c2.commission as adj,
                  c2.details as note,
                  add.lastname,
                  add.firstname,
                  d.id
             from distributor_bank_infos dbi,
                  users_home_addresses uha,
                  addresses add,
                  distributors d
        left join bonus.bonusm#{date}_commissions c1
               on d.id = c1.distributor_id
              and c1.commission_type_id != (select id from commission_types where code = 'ADJ')
        left join bonus.bonusm#{date}_manual_commissions c2
               on d.id = c2.distributor_id
              and c2.commission_type_id = (select id from commission_types where code = 'ADJ')
            where d.id = dbi.distributor_id
              and d.user_id = uha.user_id
              and add.id = uha.address_id
              and add.country_id = 1012
              and uha.is_default = true
              and uha.active = true
              #{_where}
         group by d.id, dbi.bank_account_number, dbi.bank_code,
                  add.firstname, add.lastname, c2.commission, c2.details
           having sum(c1.commission) > 0
         order by d.id
          "
    res = ActiveRecord::Base.connection.select_all(sanitize_sql(check))
    if res.count == 0
      ActiveRecord::Base.connection.execute(sanitize_sql(create))
    end
    ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
  end

  def self.monthly_unilevel(params)
    sql = "SELECT * FROM mobile.get_report_organization_UL(%d, '%s', NULL, NULL, %d);"
    ActiveRecord::Base.connection.select_all(sanitize_sql([sql, params[:distributor_id], params[:query_date].to_s, (params[:only_orders] == "true" ? 1 : 0)]))
  end
end
