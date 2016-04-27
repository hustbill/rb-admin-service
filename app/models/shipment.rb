class Shipment < ActiveRecord::Base

  belongs_to :order
  belongs_to :warehouse
  belongs_to :shipping_method
  has_many :inventory_units
  
  def decorated_attributes
    {
      "shipping-method-name" => (shipping_method.name rescue ""),
      "shipping-method-id" => shipping_method_id,
      "tracking" => tracking,
      "number" => number,
      "state" => state,
      "cost" => cost,
      "warehouse-id" => warehouse_id,
      "warehouse-name"=> (warehouse.blank? ? "Not Assigned" : warehouse.name)
    }
  end
  
  def self.toship_orders(input_params)
    begin
      input_params['warehouse_order_date'].to_date
    rescue
      input_params['warehouse_order_date'] = Time.now.strftime('%Y-%m-%d')
    end
    input_params['warehouse_order_date'] = Time.now.strftime('%Y-%m-%d') if input_params['warehouse_order_date'].strip == ""
    # search_conditions = "orders.shipment_state = 'ready' and orders.order_date >= '#{input_params['warehouse_order_date']}' and orders.order_date < '#{input_params['warehouse_order_date'].to_date.tomorrow.strftime('%Y-%m-%d')}'"
    search_conditions = ""
    if input_params[:sSearch].present?
      search_conditions << " AND orders.number = '#{input_params[:sSearch]}'"
    end

    if input_params[:warehouse_id].present?
      search_conditions << " AND shipments.warehouse_id = '#{input_params[:warehouse_id]}'"
    end

    select = "SELECT distinct shipments.number as shipment_number,
                   sq.total as package_count,
                   orders.id as order_id,
                   orders.number as order_number,
                   to_char(orders.order_date, 'yyyy-mm-dd') as order_date,
                   warehouses.name as warehouse_name,
                   coalesce(addresses.firstname || ' ' || addresses.lastname, '') as shipto_name1,
                   coalesce(addresses.joint_firstname || ' ' || addresses.joint_lastname,'') as shipto_name2,
                   coalesce(addresses.address1,'') as shipto_address1,
                   coalesce(addresses.address2,'') as shipto_address2,
                   addresses.city as shipto_city,
                   states.abbr as shipto_state,
                   addresses.zipcode as shipto_zip,
                   countries.iso as shipto_country,
                   addresses.phone as shipto_phone,
                   orders.email as shipto_email,
                   coalesce(home_address.firstname || ' ' || home_address.lastname, '') as home_name1,
                   coalesce(home_address.joint_firstname || ' ' || home_address.joint_lastname, '') as home_name2,
                   coalesce(home_address.address1,'') as home_address1,
                   coalesce(home_address.address2,'') as home_address2,
                   home_address.city as home_city,
                   home_states.abbr as home_state,
                   home_address.zipcode as home_zip,
                   home_countries.iso as home_country,
                   home_address.phone as home_phone,
                   distributors.id as distributor_id,
--                   shipping_methods.name as delivery_method,
                   case when shipping_methods.name ilike '%pick up%' then case when plocation.name is null then shipping_methods.name else plocation.name end else shipping_methods.name end as delivery_method,
                   shipments.weight as weight,
                   orders.total as invoice_total,
                   shipments.cost as freight,
                   to_char(shipments.created_at, 'yyyy-mm-dd') as shipment_created_at,
                   address_addons.address_references as reference,
                   orders.special_instructions as special_instructions
                   "
    from =    "FROM 
             (select order_id, count(1) total from shipments group by order_id having count(1) > 0) sq
             JOIN orders on sq.order_id = orders.id
             JOIN state_events on state_events.stateful_id = orders.id
             LEFT JOIN shipments ON (orders.id = shipments.order_id)
             LEFT JOIN warehouses ON (shipments.warehouse_id = warehouses.id)
             LEFT JOIN pickup_locations plocation ON (plocation.shipping_method_id = shipments.shipping_method_id and plocation.address_id = orders.ship_address_id)
             LEFT JOIN shipping_methods ON (shipments.shipping_method_id = shipping_methods.id)
             LEFT JOIN users ON (orders.user_id = users.id)

             LEFT JOIN users_home_addresses ON (users_home_addresses.user_id = users.id and users_home_addresses.is_default =true)
             LEFT JOIN addresses home_address ON (home_address.id = users_home_addresses.address_id)

             LEFT JOIN states home_states ON (home_states.id = home_address.state_id)
             LEFT JOIN countries home_countries ON (home_countries.id = home_address.country_id)
             LEFT JOIN distributors ON (users.id = distributors.user_id)
             LEFT JOIN addresses ON (orders.ship_address_id = addresses.id)
             LEFT JOIN address_addons ON (address_addons.address_id = addresses.id)
             LEFT JOIN states ON (states.id = addresses.state_id)
             LEFT JOIN countries ON (countries.id = addresses.country_id)
             LEFT JOIN currencies ON (orders.currency_id = currencies.id) "
    where =  "WHERE
                  orders.id = sq.order_id and state_events.stateful_id = orders.id and 
                  state_events.name = 'payment' and 
                  state_events.stateful_type = 'Order' and 
                  state_events.next_state = 'paid' and 
                  orders.state = 'complete' and 
                  orders.shipment_state = 'ready' and 
                  state_events.created_at >= '#{input_params['warehouse_order_date']}' and 
                  state_events.created_at < '#{input_params['warehouse_order_date'].to_date.tomorrow.strftime('%Y-%m-%d')}'
                  #{search_conditions}"
    sortorder = "ORDER by orders.id"
    limit = (input_params[:iDisplayLength].nil? ? "" : "limit #{input_params[:iDisplayLength]}")
    offset = (input_params[:iDisplayStart].nil? ? "" : "offset #{input_params[:iDisplayStart]}")

    sql = "#{select} #{from} #{where} #{sortorder} #{limit} #{offset}"
    shipments = ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
  end

  def self.toship_orders_assemble(input_params)
    begin
      input_params['warehouse_order_date'].to_date
    rescue
      input_params['warehouse_order_date'] = Time.now.strftime('%Y-%m-%d')
    end
    input_params['warehouse_order_date'] = Time.now.strftime('%Y-%m-%d') if input_params['warehouse_order_date'].strip == ""
    search_conditions = ""

    if input_params[:warehouse_id].present?
      search_conditions << " AND shipments.warehouse_id = '#{input_params[:warehouse_id]}'"
    end

    select = "SELECT distinct shipments.number as shipment_number,
                   sq.total as package_count,
                   orders.id as order_id,
                   orders.number as order_number,
                   to_char(orders.order_date, 'yyyy-mm-dd') as order_date,
                   warehouses.name as warehouse_name,
                   coalesce(addresses.firstname || ' ' || addresses.lastname, '') as shipto_name1,
                   coalesce(addresses.joint_firstname || ' ' || addresses.joint_lastname,'') as shipto_name2,
                   coalesce(addresses.address1,'') as shipto_address1,
                   coalesce(addresses.address2,'') as shipto_address2,
                   addresses.city as shipto_city,
                   states.abbr as shipto_state,
                   addresses.zipcode as shipto_zip,
                   countries.iso as shipto_country,
                   addresses.phone as shipto_phone,
                   orders.email as shipto_email,
                   coalesce(home_address.firstname || ' ' || home_address.lastname, '') as home_name1,
                   coalesce(home_address.joint_firstname || ' ' || home_address.joint_lastname, '') as home_name2,
                   coalesce(home_address.address1,'') as home_address1,
                   coalesce(home_address.address2,'') as home_address2,
                   home_address.city as home_city,
                   home_states.abbr as home_state,
                   home_address.zipcode as home_zip,
                   home_countries.iso as home_country,
                   home_address.phone as home_phone,
                   distributors.id as distributor_id,
--                   shipping_methods.name as delivery_method,
                   case when shipping_methods.name ilike '%pick up%' then case when plocation.name is null then shipping_methods.name else plocation.name end else shipping_methods.name end as delivery_method,
                   shipments.weight as weight,
                   orders.total as invoice_total,
                   shipments.cost as freight,
                   to_char(shipments.created_at, 'yyyy-mm-dd') as shipment_created_at,
                   address_addons.address_references as reference,
                   orders.special_instructions as special_instructions
                   "
    from =    "FROM 
             (select order_id, count(1) total from shipments group by order_id having count(1) > 0) sq
             JOIN orders on sq.order_id = orders.id
             JOIN state_events on state_events.stateful_id = orders.id
             LEFT JOIN shipments ON (orders.id = shipments.order_id)
             LEFT JOIN warehouses ON (shipments.warehouse_id = warehouses.id)
             LEFT JOIN pickup_locations plocation ON (plocation.shipping_method_id = shipments.shipping_method_id and plocation.address_id = orders.ship_address_id)
             LEFT JOIN shipping_methods ON (shipments.shipping_method_id = shipping_methods.id)
             LEFT JOIN users ON (orders.user_id = users.id)
             
             LEFT JOIN users_home_addresses ON (users_home_addresses.user_id = users.id and users_home_addresses.is_default =true)
             LEFT JOIN addresses home_address ON (home_address.id = users_home_addresses.address_id)

             LEFT JOIN states home_states ON (home_states.id = home_address.state_id)
             LEFT JOIN countries home_countries ON (home_countries.id = home_address.country_id)
             LEFT JOIN distributors ON (users.id = distributors.user_id)
             LEFT JOIN addresses ON (orders.ship_address_id = addresses.id)
             LEFT JOIN address_addons ON (address_addons.address_id = addresses.id)
             LEFT JOIN states ON (states.id = addresses.state_id)
             LEFT JOIN countries ON (countries.id = addresses.country_id)
             LEFT JOIN currencies ON (orders.currency_id = currencies.id) "
    where =  "WHERE
                  orders.id = sq.order_id AND 
                  state_events.stateful_id = orders.id AND 
                  state_events.name = 'payment' AND 
                  state_events.stateful_type = 'Order' AND 
                  state_events.next_state = 'paid' AND
                  orders.state = 'complete' AND 
                  orders.shipment_state = 'assemble' AND 
                  state_events.created_at >= '#{input_params['warehouse_order_date']}' AND 
                  state_events.created_at < '#{input_params['warehouse_order_date'].to_date.tomorrow.strftime('%Y-%m-%d')}'
                  #{search_conditions}"
    sortorder = "ORDER by orders.id"

    sql = "#{select} #{from} #{where} #{sortorder}"
    shipments = ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
  end

  def self.shipment_byitem(input_params)
    begin
      input_params['warehouse_order_date'].to_date
    rescue
      input_params['warehouse_order_date'] = Time.now.strftime('%Y-%m-%d')
    end
    input_params['warehouse_order_date'] = Time.now.strftime('%Y-%m-%d') if input_params['warehouse_order_date'].strip == ""

    search_conditions = ""

    select = "SELECT distinct shipments.number as shipment_number,
                 orders.number as order_number,
                 line_items.line_no as line_number,
                 variants.sku as item_code,
                 line_items.quantity as quantity,
                 products.name as item_name,
                 products.description as item_description"
    from  = "FROM
                shipments, orders, line_items, variants, products, state_events"
    where = "WHERE
                shipments.order_id = orders.id AND
                line_items.order_id = orders.id AND
                line_items.variant_id = variants.id AND
                variants.product_id = products.id AND 
                state_events.stateful_id = orders.id AND 
                state_events.name = 'payment' AND
                state_events.stateful_type = 'Order' AND 
                state_events.next_state = 'paid' AND
                orders.shipment_state = 'ready' AND 
                state_events.created_at >= '#{input_params['warehouse_order_date']}' AND 
                state_events.created_at < '#{input_params['warehouse_order_date'].to_date.tomorrow.strftime('%Y-%m-%d')}'"
    if input_params[:warehouse_id].present?
      search_conditions << " AND shipments.warehouse_id = '#{input_params[:warehouse_id]}'"
    end
            
    sql = "#{select} #{from} #{where} #{search_conditions} order by orders.number asc, line_items.line_no asc"
    ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
  end

  def self.shipment_byitem_assemble(input_params)
    begin
      input_params['warehouse_order_date'].to_date
    rescue
      input_params['warehouse_order_date'] = Time.now.strftime('%Y-%m-%d')
    end
    input_params['warehouse_order_date'] = Time.now.strftime('%Y-%m-%d') if input_params['warehouse_order_date'].strip == ""
    search_conditions = ""

    select = "SELECT distinct shipments.number as shipment_number,
                 orders.number as order_number,
                 line_items.line_no as line_number,
                 variants.sku as item_code,
                 line_items.quantity as quantity,
                 products.name as item_name,
                 products.description as item_description"
    from  = "FROM
                shipments, orders, line_items, variants, products, state_events"
    where = "WHERE
                shipments.order_id = orders.id AND
                line_items.order_id = orders.id AND
                line_items.variant_id = variants.id AND
                variants.product_id = products.id and state_events.stateful_id = orders.id and state_events.name = 'payment' and
                state_events.stateful_type = 'Order' and state_events.next_state = 'paid' and
                orders.shipment_state = 'assemble' and state_events.created_at >= '#{input_params['warehouse_order_date']}' and
                state_events.created_at < '#{input_params['warehouse_order_date'].to_date.tomorrow.strftime('%Y-%m-%d')}'"
    if input_params[:warehouse_id].present?
      search_conditions << " AND shipments.warehouse_id = '#{input_params[:warehouse_id]}'"
    end

    sql = "#{select} #{from} #{where} #{search_conditions} order by orders.number asc, line_items.line_no asc"
    ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
  end

  def self.transit_to_assemble(order_id_list)
    return false if order_id_list.empty?
    _ids = order_id_list.join(',')
    sqlcmd = "select set_batch_orders_to_shipment_state('" + _ids + "','assemble','assemble')"
    ActiveRecord::Base.connection.select_all(sanitize_sql(sqlcmd))
  end

end
