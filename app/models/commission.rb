class Commission < ActiveRecord::Base
  COMMISSIONS_MONTLY_STARTDATE = Date.new(2014,03,01)
  COMMISSIONS_WEEKLY_STARTDATE = Date.new(2012,03,19)
  COMMISSIONS_RANK_STARTDATE   = Date.new(2014,03,01)
  ############################################################################
  def self.datatable_columns(column_id)
    case column_id.to_i
    when 0 
      return "country"
    when 1 
      return "uncompressed_level"
    when 2 
      return "compressed_level"
    when 3 
      return "distributor_id"
    when 4 
      return "full_name"
    when 5 
      return "commission_volume"
    when 6 
      return "percentage_paid"
    when 7 
      return "commission_amount"
    else
      return "country"
    end
  end
  
  ############################################################################
  def self.get_commissions_week(query_params)
    start_date = query_params[:start_date]
    country_iso = query_params[:country_iso]
    prevmonth_start_date = (start_date.to_date << 1).strftime("%Y%m01")
    limit = query_params[:limit]
    offset = query_params[:offset]
    distributor_list_dt = []
    distributor_list_retail = []
    distributor_list_ft = []

    distributor_info = {}

    weekly_commission = {}

    sql_dualteam = "select t1.distributor_id, t1.country_home, t2.rank_code as paid_rank, t3.rank_code as current_rank, t1.pvdt_bycountry,
                           t1.full_name, t1.earning_dualteam, t1.earning_dualteam_local, dist.social_security_number
                    from get_commissions_dualteam('#{start_date.to_date.strftime("%Y%m%d")}', #{limit}, #{offset}) t1
                         left join distributors dist on (dist.id = t1.distributor_id)
                         left join client_ranks t2 on (t1.paid_rank = t2.rank_identity)
                         left join client_ranks t3 on (t1.current_rank = t3.rank_identity)"
#                    where t1.paid_rank = t2.rank_identity and t1.current_rank = t3.rank_identity"
    if country_iso.present?
        sql_dualteam << " where t1.country_home = '#{country_iso}'"
    end
    ActiveRecord::Base.connection.select_all(sanitize_sql(sql_dualteam)).each do |rec|
        dist_id = rec['distributor_id']
        distributor_list_dt << dist_id
        distributor_info.merge!({dist_id =>  rec['country_home'].to_s + ":" + rec['paid_rank'].to_s + ":" + rec['current_rank'].to_s + ":" + rec['full_name'].to_s + ":" + rec['social_security_number'].to_s})

        weekly_commission[dist_id] = {} if weekly_commission[dist_id].nil?
        dtvol = {}
        sum_dtvol = 0
        rec['pvdt_bycountry'].split(':').each do |country_dtvol|
           cd_ary = country_dtvol.split('_')
           dtvol[cd_ary[0]] = cd_ary[1].to_f
           sum_dtvol += cd_ary[1].to_f
        end

        if sum_dtvol == 0
          country_home = rec['country_home'].to_s
          weekly_commission[dist_id][country_home] = {} if weekly_commission[dist_id][country_home].nil?
          weekly_commission[dist_id][country_home]['dualteam_commission'] = rec['earning_dualteam'].to_f
          weekly_commission[dist_id][country_home]['dualteam_commission_local'] = rec['earning_dualteam_local'].to_f
        else
          dtvol.each do |country,volume|
            weekly_commission[dist_id][country] = {} if weekly_commission[dist_id][country].nil?
            weekly_commission[dist_id][country]['dualteam_commission'] = rec['earning_dualteam'].to_f * volume.to_f / sum_dtvol.to_f
            weekly_commission[dist_id][country]['dualteam_commission_local'] = rec['earning_dualteam_local'].to_f * volume.to_f / sum_dtvol.to_f
          end
        end
    end

    sql_retail = "select 
                        t1.distributor_id,
                        t5.iso AS home_country,
                        t7.rank_code AS qualified_rank,
                        t8.rank_code AS paid_rank, 
                        coalesce(t4.firstname, '') || coalesce(' ' || t4.lastname, '') AS name,
                        t1.order_country AS commission_country,
                        t1.item_total - t1.wholesale_total AS retail_commission,
                        t1.item_total_reverse - t1.wholesale_total_reverse AS retail_commission_return,
                        t1.currency_iso AS retail_currency,
                        (t1.item_total - t1.wholesale_total) / t9.convert_rate * t10.convert_rate AS retail_commission_local,
                        (t1.item_total_reverse - t1.wholesale_total_reverse) / t9.convert_rate * t10.convert_rate AS retail_commission_return_local,
                        t2.social_security_number
                    from 
                        distributors t2, users t3, addresses t4, countries t5, client_fxrates t9, client_fxrates t10, get_retail_total('#{start_date}', 2) t1
                        left join bonus.bonusm#{prevmonth_start_date} t6 ON (t1.distributor_id = t6.id)
                        left join client_ranks t7 ON (t6.current_rank = t7.rank_identity)
                        left join client_ranks t8 ON (t6.paid_rank = t8.rank_identity)
                    where
                        t9.currency_id = t1.currency_id and t5.commission_currency_id = t10.currency_id and
                        t1.distributor_id = t2.id and t2.user_id = t3.id and t3.sold_address_id = t4.id and t4.country_id = t5.id"
#                        and t1.distributor_id = t6.id and t6.current_rank = t7.rank_identity and t6.paid_rank = t8.rank_identity"
    if offset != "null" && limit != "null"
        sql_retail << " and t2.id in (#{distributor_list_dt.join(',')})"
    end
    if country_iso.present?
        sql_retail << " and t5.iso = '#{country_iso}'"
    end
    ActiveRecord::Base.connection.select_all(sanitize_sql(sql_retail)).each do |rec|
        dist_id = rec['distributor_id']
        distributor_list_retail << dist_id
        distributor_info.merge!({dist_id => rec['home_country'].to_s + ":" + rec['paid_rank'].to_s + ":" + rec['qualified_rank'].to_s + ":" + rec['name'].to_s + ":" + rec['social_security_number'].to_s})
        weekly_commission[dist_id] = {}   if weekly_commission[dist_id].nil?
        commission_country = rec['commission_country']
        weekly_commission[dist_id][commission_country] = {}  if weekly_commission[dist_id][commission_country].nil?
        weekly_commission[dist_id][commission_country]['retail_commission'] = rec['retail_commission'].to_f - rec['retail_commission_return'].to_f
        weekly_commission[dist_id][commission_country]['retail_commission_currency'] = rec['retail_currency']
        weekly_commission[dist_id][commission_country]['retail_commission_local'] = rec['retail_commission_local'].to_f - rec['retail_commission_return_local'].to_f
    end
        
    sql_fasttrack = "select 
                        t1.distributor_id,
                        t5.iso AS home_country,
                        t7.rank_code AS qualified_rank,
                        t8.rank_code AS paid_rank, 
                        coalesce(t4.firstname, '') || coalesce(' ' || t4.lastname, '') AS name,
                        t1.order_country AS commission_country,
                        t1.fasttrack_volume AS fasttrack_volume,
                        t1.fasttrack_volume_reverse AS fasttrack_volume_return,
                        CASE t1.order_country WHEN 'PH' THEN t1.fasttrack_volume / t9.convert_rate * t10.convert_rate * 40
                                              WHEN 'TW' THEN t1.fasttrack_volume / t9.convert_rate * t10.convert_rate * 30
                                              WHEN 'TH' THEN t1.fasttrack_volume / t9.convert_rate * t10.convert_rate * 30
                                              WHEN 'MY' THEN t1.fasttrack_volume / t9.convert_rate * t10.convert_rate * 3
                                              WHEN 'M1' THEN t1.fasttrack_volume / t9.convert_rate * t10.convert_rate * 3
                                              WHEN 'JP' THEN t1.fasttrack_volume / t9.convert_rate * t10.convert_rate * 100
                                              WHEN 'KE' THEN t1.fasttrack_volume / t9.convert_rate * t10.convert_rate * 85
                                              WHEN 'SG' THEN t1.fasttrack_volume / t9.convert_rate * t10.convert_rate * 1.25
                                              WHEN 'RU' THEN t1.fasttrack_volume / t9.convert_rate * t10.convert_rate * 32
                                              WHEN 'KZ' THEN t1.fasttrack_volume / t9.convert_rate * t10.convert_rate * 32
                                              WHEN 'BY' THEN t1.fasttrack_volume / t9.convert_rate * t10.convert_rate * 32
                                              WHEN 'UA' THEN t1.fasttrack_volume / t9.convert_rate * t10.convert_rate * 8.1
                                              ELSE t1.fasttrack_volume / t9.convert_rate * t10.convert_rate
                                              END AS fasttrack_volume_local,
                        CASE t1.order_country WHEN 'PH' THEN t1.fasttrack_volume_reverse / t9.convert_rate * t10.convert_rate * 40
                                              WHEN 'TW' THEN t1.fasttrack_volume_reverse / t9.convert_rate * t10.convert_rate * 30
                                              WHEN 'TH' THEN t1.fasttrack_volume_reverse / t9.convert_rate * t10.convert_rate * 30
                                              WHEN 'MY' THEN t1.fasttrack_volume_reverse / t9.convert_rate * t10.convert_rate * 3
                                              WHEN 'M1' THEN t1.fasttrack_volume_reverse / t9.convert_rate * t10.convert_rate * 3
                                              WHEN 'JP' THEN t1.fasttrack_volume_reverse / t9.convert_rate * t10.convert_rate * 100
                                              WHEN 'KE' THEN t1.fasttrack_volume_reverse / t9.convert_rate * t10.convert_rate * 85
                                              WHEN 'SG' THEN t1.fasttrack_volume_reverse / t9.convert_rate * t10.convert_rate * 1.25
                                              WHEN 'RU' THEN t1.fasttrack_volume_reverse / t9.convert_rate * t10.convert_rate * 32
                                              WHEN 'KZ' THEN t1.fasttrack_volume_reverse / t9.convert_rate * t10.convert_rate * 32
                                              WHEN 'BY' THEN t1.fasttrack_volume_reverse / t9.convert_rate * t10.convert_rate * 32
                                              WHEN 'UA' THEN t1.fasttrack_volume_reverse / t9.convert_rate * t10.convert_rate * 8.1
                                              ELSE t1.fasttrack_volume_reverse / t9.convert_rate * t10.convert_rate
                                              END AS fasttrack_volume_return_local,
                        t2.social_security_number
                    from 
                        distributors t2, users t3, addresses t4, countries t5, client_fxrates t9, client_fxrates t10, get_fasttrack_total('#{start_date}', 2) t1
                        left join bonus.bonusm#{prevmonth_start_date} t6 ON (t1.distributor_id = t6.id)
                        left join client_ranks t7 ON (t6.current_rank = t7.rank_identity)
                        left join client_ranks t8 ON (t6.paid_rank = t8.rank_identity)
                    where
                        t1.distributor_id = t2.id and t2.user_id = t3.id and t3.sold_address_id = t4.id and t4.country_id = t5.id 
                        and t9.currency_id = t1.currency_id and t5.commission_currency_id = t10.currency_id and (t1.fasttrack_volume > 0 or t1.fasttrack_volume_reverse >0)"
#                        and t1.distributor_id = t6.id and t6.current_rank = t7.rank_identity and t6.paid_rank = t8.rank_identity
    if offset != "null" && limit != "null"
        sql_fasttrack << " and t2.id in (#{distributor_list_dt.join(',')})"
    end
    if country_iso.present?
        sql_fasttrack << " and t5.iso = '#{country_iso}'"
    end
    ActiveRecord::Base.connection.select_all(sanitize_sql(sql_fasttrack)).each do |rec|
        dist_id = rec['distributor_id']
        distributor_list_ft << dist_id
        distributor_info.merge!({dist_id => rec['home_country'].to_s + ":" + rec['paid_rank'].to_s + ":" + rec['qualified_rank'].to_s + ":" + rec['name'].to_s + ":" + rec['social_security_number'].to_s })
        weekly_commission[dist_id] = {}   if weekly_commission[dist_id].nil?
        commission_country = rec['commission_country']
        weekly_commission[dist_id][commission_country] = {}  if weekly_commission[dist_id][commission_country].nil?
        weekly_commission[dist_id][commission_country]['fasttrack_volume'] = rec['fasttrack_volume'].to_f - rec['fasttrack_volume_return'].to_f
        weekly_commission[dist_id][commission_country]['fasttrack_volume_local'] = rec['fasttrack_volume_local'].to_f - rec ['fasttrack_volume_return_local'].to_f
    end

    commission_week_ary = []
    (distributor_list_dt + distributor_list_retail + distributor_list_ft).uniq.sort{|x,y| x.to_i <=> y.to_i}.each do |dist_id|
        weekly_commission[dist_id].each do |country, hash_values|
           hash_rec = {}
           hash_rec['distributor_id'] = dist_id
           distinfo = distributor_info[dist_id].split(':')
           hash_rec['country_home'] = distinfo[0]
           hash_rec['paid_rank'] = distinfo[1]
           hash_rec['current_rank'] = distinfo[2]
           hash_rec['full_name'] = distinfo[3]
           hash_rec['social_security_number'] = distinfo[4]

           hash_rec['commission_country'] = country
           hash_rec['earning_dualteam'] = "%.6f" % (hash_values['dualteam_commission'].nil? ? 0 : hash_values['dualteam_commission'].to_f)
           hash_rec['earning_dualteam_local'] =  "%.6f" % (hash_values['dualteam_commission_local'].nil? ? 0 : hash_values['dualteam_commission_local'].to_f)
           hash_rec['earning_retail'] = "%.4f" % (hash_values['retail_commission'].nil? ? 0 : hash_values['retail_commission'].to_f)
           hash_rec['earning_retail_currency'] = hash_values['retail_commission_currency'].nil? ? 'n/a' : hash_values['retail_commission_currency']
           hash_rec['earning_retail_local'] = "%.4f" % (hash_values['retail_commission_local'].nil? ? 0 : hash_values['retail_commission_local'].to_f)
           hash_rec['earning_fasttrack'] =  "%.4f" % (hash_values['fasttrack_volume'].nil? ? 0 : hash_values['fasttrack_volume'].to_f)
     hash_rec['earning_fasttrack_local'] = "%.4f" % (hash_values['fasttrack_volume_local'].nil? ? 0 : hash_values['fasttrack_volume_local'].to_f)
           hash_rec['total_earned'] = "%.4f" % (hash_rec['earning_dualteam_local'].to_f + hash_rec['earning_retail_local'].to_f + hash_rec['earning_fasttrack_local'].to_f)

           commission_week_ary << hash_rec  if (hash_rec['total_earned'].to_f).abs > 0.00001
        end
    end
#    if offset != "null" && limit != "null"
#        return commission_week_ary[offset.to_i, limit.to_i]
#    else
        return commission_week_ary
#    end
  end

  ############################################################################
  def self.get_commissions_retail(query_params)
    start_date = query_params[:start_date]
    commissions_retail = []
    sql = "select t1.*, ad.firstname, ad.lastname from get_retail_total('#{start_date}',2) t1, distributors d, users_home_addresses uh, addresses ad where t1.distributor_id = d.id and d.user_id = uh.user_id and uh.address_id = ad.id and uh.active = true and uh.is_default = true;"
    ActiveRecord::Base.connection.select_all(sanitize_sql(sql)).each do |e|
      commission_detail = {}
      commission_detail[:distributor_id]   = e['distributor_id']
      commission_detail[:distributor_name] = "#{e['lastname']}, #{e['firstname']}"
      commission_detail[:country]          = e['order_country']
      commission_detail[:sales_price]      = e['item_total'].to_f - e['item_total_reverse'].to_f
      commission_detail[:wholesale_price]  = e['wholesale_total'].to_f - e['wholesale_total_reverse'].to_f
      commission_detail[:currency_symbol]  = e['currency_iso']
      commissions_retail.push(commission_detail)
    end
    return commissions_retail
  end
  
  ############################################################################
  def self.get_commissions_fasttrack(query_params)
    start_date = query_params[:start_date]
    commissions_retail = []
    sql = "select t1.*, ad.firstname, ad.lastname from get_fasttrack_total('#{start_date}',2) t1, distributors d, users_home_addresses uh, addresses ad where t1.distributor_id = d.id and d.user_id = uh.user_id and uh.address_id = ad.id and uh.active = true and uh.is_default = true;"
    ActiveRecord::Base.connection.select_all(sanitize_sql(sql)).each do |e|
      commission_detail = {}
      commission_detail[:distributor_id]   = e['distributor_id']
      commission_detail[:distributor_name] = "#{e['lastname']}, #{e['firstname']}"
      commission_detail[:country]          = e['order_country']
      commission_detail[:sales_price]      = e['sales_price']
      commission_detail[:fasttrack_volume] = e['fasttrack_volume']
      commission_detail[:currency_symbol]  = e['currency_iso']
      commissions_retail.push(commission_detail)
    end
    return commissions_retail
  end
  
  
  ############################################################################
  def self.get_commissions_dualteam(query_params)
    distributor_id = query_params[:distributor_id]
    
    commissions_dualteam = {}

    commission_data_table_name = Commission.formatted_weekly_data_table_name(query_params[:start_date])
    commission_detail_table_name = commission_data_table_name + "_dualteamdetails"

    if not ActiveRecord::Base.connection.table_exists?(commission_data_table_name)
      logger.error("ERROR: distributor_id[#{distributor_id}] Commission::get_commissions_dualteam: #{commission_data_table_name} table doesn't exist")
      return {}
    end

    if not ActiveRecord::Base.connection.table_exists?(commission_detail_table_name)
      logger.error("ERROR: distributor_id[#{distributor_id}] Commission::get_commissions_dualteam: #{commission_detail_table_name} table doesn't exist")
      return {}
    end   

    sql = %Q(select bonus as dt_bonus,
                    bonus_percentage as percentage_paid,
                    prev_pv_co_left as begin_vol_left,
                    prev_pv_co_right as begin_vol_right,
                    current_pv_co_left as end_vol_left,
                    current_pv_co_right as end_vol_right,
                    pv_left_sum as new_vol_left,
                    pv_right_sum as new_vol_right,
                    pvdt_bycountry as dt_vol_bycountry
              from #{commission_detail_table_name}
              where distributor_id=#{distributor_id})
    if query_params[:start_date].to_date >= "2013-09-09".to_date     # date is specified here because prior to July 2013, the dualteamdetails table schema is different 
       sql = %Q(select bonus as dt_bonus,
                    bonus_percentage as percentage_paid,
                    prev_pv_co_left as begin_vol_left,
                    prev_pv_co_right as begin_vol_right,
                    current_pv_co_left as end_vol_left,
                    current_pv_co_right as end_vol_right,
                    pv_left_sum as new_vol_left,
                    pv_right_sum as new_vol_right,
                    pvdt_bycountry as dt_vol_bycountry,
                    pvdt_sum_ul_all as pvdt_sum_ul_all,
                    pvdt_pay_volume as pvdt_pay_volume,
                    bonus_no_cap as bonus_no_cap,
                    bonus_cap as bonus_cap,
                    bonus_cap_adjusted as bonus_cap_adjusted,
                    pvdt_sum_all,
                    cycle_count as cycle_count_personal,
                    cycle_count_total,
                    0 as pvdt_sum_paid,
                    0 as universal_cap_amount
              from #{commission_detail_table_name}
              where distributor_id=#{distributor_id})
    end
                    
    if query_params[:start_date].to_date >= "2013-09-09".to_date     # date is specified here because prior to July 2013, the dualteamdetails table schema is different 
     ActiveRecord::Base.connection.select_all(sanitize_sql(sql)).each do |d|
      commissions_dualteam[:dt_bonus] = d['dt_bonus']
      commissions_dualteam[:percentage_paid] = d['percentage_paid']
      commissions_dualteam[:begin_vol_left] = d['begin_vol_left']
      commissions_dualteam[:begin_vol_right] = d['begin_vol_right']
      commissions_dualteam[:end_vol_left] = d['end_vol_left']
      commissions_dualteam[:end_vol_right] = d['end_vol_right']
      commissions_dualteam[:current_vol_left] = d['new_vol_left']
      commissions_dualteam[:current_vol_right] = d['new_vol_right']
      commissions_dualteam[:sum_ul_all] = d['pvdt_sum_ul_all']
      commissions_dualteam[:pay_volume] = d['pvdt_pay_volume']
      commissions_dualteam[:bonus_no_cap] = d['bonus_no_cap']
      commissions_dualteam[:bonus_cap] = d['bonus_cap']
      commissions_dualteam[:pvdt_sum_all] = d['pvdt_sum_all']
      commissions_dualteam[:pvdt_sum_paid] = d['pvdt_sum_paid']
      commissions_dualteam[:bonus_cap_adjusted] = d['bonus_cap_adjusted']
      commissions_dualteam[:cycle_count_personal] = d['cycle_count_personal']
      commissions_dualteam[:cycle_count_total] = d['cycel_count_total']
      commissions_dualteam[:universal_cap_amount] = d['universal_cap_amount']
     end
    else
     ActiveRecord::Base.connection.select_all(sanitize_sql(sql)).each do |d|
      commissions_dualteam[:dt_bonus] = d['dt_bonus']
      commissions_dualteam[:percentage_paid] = d['percentage_paid']
      commissions_dualteam[:begin_vol_left] = d['begin_vol_left']
      commissions_dualteam[:begin_vol_right] = d['begin_vol_right']
      commissions_dualteam[:end_vol_left] = d['end_vol_left']
      commissions_dualteam[:end_vol_right] = d['end_vol_right']
      commissions_dualteam[:current_vol_left] = d['new_vol_left']
      commissions_dualteam[:current_vol_right] = d['new_vol_right']
     end
    end
    
    sql = %Q(select prev_pv_co_left_dt as beg_vol_left,
                    prev_pv_co_right_dt as beg_vol_right
             from #{commission_data_table_name}
             where id=#{distributor_id})
             
    ActiveRecord::Base.connection.select_all(sanitize_sql(sql)).each do |d|
      commissions_dualteam[:imatrix_beg_vol_left] = d['beg_vol_left']
      commissions_dualteam[:imatrix_beg_vol_right] = d['beg_vol_right']
    end

    commissions_dualteam[:flushing_pt_left] = 0
    commissions_dualteam[:flushing_pt_right] = 0

    flushing_table_name = "bonus.bonusw#{query_params[:start_date].gsub('-', '')}_flushingdetails"
    if ActiveRecord::Base.connection.table_exists?(flushing_table_name)
      sql = "select * from #{flushing_table_name} where distributor_id = #{distributor_id}"
      pts = ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
      if pts.size > 0
        commissions_dualteam[:flushing_pt_left] = pts.first['flushing_pt_left']
        commissions_dualteam[:flushing_pt_right] = pts.first['flushing_pt_right']
      end
    end

    commissions_dualteam
  end
  
  
  ############################################################################
  def self.get_commissions_month_query_params(user, input_params)
    query_params = {}
    
    query_params[:limit_size] = input_params[:iDisplayLength]
    query_params[:offset_size] = input_params[:iDisplayStart]
    query_params[:distributor_id] = user.distributor.id
    
    query_params[:start_date] = (input_params[:commission_date].present?) ?  input_params[:commission_date] : Commission.monthly_start_date(Time.now.strftime('%Y-%m-%d')) 
#                                                                          : Commission.monthly_start_date(-30.day.from_now.strftime('%Y-%m-%d'))
                                                                          
    query_params[:int_fxrate] = user.country.commission_currency.client_fxrate.convert_rate
    query_params[:commission_type] = (input_params[:commission_type].present?) ?  input_params[:commission_type] : "unilevel" 
    query_params[:sort_order] = (input_params[:sSortDir_0].nil? || input_params[:sSortDir_0] == "asc") ? "ASC" : "DESC"
    # offset the column to sort, e.g. :iSortCol_0, by 1
    query_params[:column_name] = input_params[:iSortCol_0].nil? ? "compressed_level" : self.datatable_columns(input_params[:iSortCol_0].to_d - 1)
    query_params[:search_string] = (input_params[:sSearch].present?) ? input_params[:sSearch] : ""
    query_params[:sEcho] = input_params[:sEcho].nil? ? -1 : input_params[:sEcho].to_i 
    
    return query_params     
  end
  
  ############################################################################
  # UL, UL match, Generation
  def self.get_commissions_month(query_params)
    commission_detail_table_name = Commission.formatted_monthly_data_table_name(query_params[:start_date]) + "_" + query_params[:commission_type] + "details"

    if not ActiveRecord::Base.connection.table_exists?(commission_detail_table_name)
      logger.error("ERROR: distributor_id[#{query_params[:distributor_id]}] Commission::get_commissions_month: #{commission_detail_table_name} table doesn't exist")
      return {:aaData => []}        # return the format expected by datatable
    end

    additional_select_field = ""
    if query_params[:commission_type] == "unilevel"
      commission_volume_type = "child_pv_ul"
      additional_select_field =  "t1.order_info as order_info,"
    elsif query_params[:commission_type] == "unilevelmatch"
      commission_volume_type = "child_ul_bonus"
    else
      commission_volume_type = "child_total_generation_pv_ul"
    end
    query_params[:limit_size] = query_params[:limit_size] || 25 
    query_params[:offset_size] = query_params[:offset_size] || 0
    select = "SELECT t1.bonus as commission_amount,
                     t1.child_id as distributor_id,
                     t4.firstname || ' ' || t4.lastname as full_name,
                     t1.compressed_level,
                     t1.uncompressed_level,
                     t1.#{commission_volume_type} as commission_volume,
                     t1.bonus/t1.#{commission_volume_type} as percentage_paid,
                     #{additional_select_field}
                     t5.iso as country"

    from  = "FROM #{commission_detail_table_name} t1, users t2, distributors t3, addresses t4, countries t5"
    conditions = "WHERE t1.distributor_id=#{query_params[:distributor_id]} and
                        t1.child_id = t3.id and
                        t1.#{commission_volume_type} <> 0 and
                        t3.user_id = t2.id and
                        t2.sold_address_id = t4.id and
                        ((CAST (t1.child_id AS text)) ~* '#{query_params[:search_string]}' or
                        t4.firstname || ' ' || t4.lastname ~* '#{query_params[:search_string]}') and
                        t4.country_id = t5.id"
    order = "ORDER by #{query_params[:column_name]} #{query_params[:sort_order]}"
    limit = "limit #{query_params[:limit_size]}"
    offset = "offset #{query_params[:offset_size]}"

    sql = "#{select} #{from} #{conditions} #{order} #{limit} #{offset}"
    monthly_commission_array = ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
    aadata = []
    monthly_commission_array.each do |distributor_commission|
      hash_aadata_element = { "0" => "<img src='/images/og-commissionsopen.png'>", 
                              "1" => distributor_commission['country'], 
                              "2" => distributor_commission['uncompressed_level'], 
                              "3" => distributor_commission['compressed_level'], 
                              "4" => distributor_commission['distributor_id'], 
                              "5" => distributor_commission['full_name'], 
                              "6" => distributor_commission['commission_volume'].to_f, 
                              "7" => (distributor_commission['percentage_paid'].to_f.round(2)*100).to_s + '%',
                              "8" => distributor_commission['commission_amount'].to_f.round(2),
                              "9" => (distributor_commission['commission_amount'].to_f * query_params[:int_fxrate]).round(2)
                             }
      if query_params[:commission_type] == "unilevel"
        order_details = []
        order_count = distributor_commission['order_info'].split(':').size
        distributor_commission['order_info'].split(':').each do |order|
          order_info = order.split('|') 
          order_details << [ order_info[0], order_info[1], order_info[2], order_info[3], order_info[4], order_info[5] ]
        end
        hash_aadata_element["extra"] = order_details
      end
      aadata << hash_aadata_element
    end
        
    commissions = { :aaData => aadata }
    
#    sql = "SELECT count(*) as count 
#           FROM #{commission_detail_table_name} 
#           WHERE distributor_id=#{query_params[:distributor_id]}"
#    total_count = ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
#    commissions[:iTotalRecords] = total_count[0]['count']
         
    sql = "select count(*) as count #{from} #{conditions}"
    selected_count = ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
    commissions[:iTotalRecords] = selected_count[0]['count']
    commissions[:iTotalDisplayRecords] = selected_count[0]['count']

    commissions[:sEcho] = query_params[:sEcho]
    return commissions
  end

  ############################################################################
  def self.get_commissions_rank(query_params)
    rank_report = {current: {}, prev: {}}
    #sql = "select
    #         curr_m_b_lifetime_rank       as lifetime_rank_id_current,
    #         curr_m_b_lifetime_pvq        as lifetime_pvq_current,
    #         curr_m_b_prev_pvq            as prev_pvq_current,
    #         curr_m_b_order_info          as order_info_current,
    #         curr_m_rd_current_rank       as qualified_rank_id_current,
    #         curr_m_rd_paid_rank          as paid_rank_id_current,
    #         curr_m_rd_pvq               as pvq_current,
    #         curr_m_rd_pgv30              as pgv30_current,
    #         curr_m_rd_pgv40              as pgv40_current,
    #         curr_m_rd_active             as active_current,
    #         curr_m_rd_pv_dt_sum_left     as month_pgdt_sum_left_current,
    #         curr_m_rd_pv_dt_sum_right    as month_pgdt_sum_right_current,
    #         curr_m_rd_pvq_rd + curr_m_rd_child_pgv_rd  as pgv_current,
    #         curr_w_dt_pv_left_sum        as week_pgdt_sum_left_current,
    #         curr_w_dt_pv_right_sum       as week_pgdt_sum_right_current,
    #
    #         prev_m_b_lifetime_rank       as lifetime_rank_id_previous,
    #         prev_m_b_lifetime_pvq        as lifetime_pvq_previous,
    #         prev_m_b_prev_pvq            as prev_pvq_previous,
    #         prev_m_b_order_info          as order_info_previous,
    #         prev_m_rd_current_rank       as qualified_rank_id_previous,
    #         prev_m_rd_paid_rank          as paid_rank_id_previous,
    #         prev_m_rd_pvq               as pvq_previous,
    #         prev_m_rd_pgv30              as pgv30_previous,
    #         prev_m_rd_pgv40              as pgv40_previous,
    #         prev_m_rd_active             as active_previous,
    #         prev_m_rd_pv_dt_sum_left     as month_pgdt_sum_left_previous,
    #         prev_m_rd_pv_dt_sum_right    as month_pgdt_sum_right_previous,
    #         prev_m_rd_pvq_rd + prev_m_rd_child_pgv_rd as pgv_previous,
    #         prev_w_dt_pv_left_sum        as week_pgdt_sum_left_previous,
    #         prev_w_dt_pv_right_sum       as week_pgdt_sum_right_previous
    #
    #       from get_distributor_info_detail(#{query_params[:distributor_id]},'#{query_params[:start_date]}')"

    table_name            = Commission.formatted_monthly_data_table_name(query_params[:start_date]) + '_rankdetails'
    prev_month_table_name = Commission.formatted_monthly_data_table_name(query_params[:prev_month_date]) + '_rankdetails'

    {current: table_name, prev: prev_month_table_name}.each do |t|
      sql    = "select * from #{t[1]} where distributor_id = #{query_params[:distributor_id]}"
      result = ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
      unless result.empty?
        rank_sql = "select * from client_ranks where rank_identity = #{result[0]['paid_rank']}"
        rr       =  ActiveRecord::Base.connection.select_all(sanitize_sql(rank_sql))
        rank_report[t[0]][:rank_name] = rr[0]['name'] unless rr.empty?
      end
    end

    # current_month_order_info
    #rank_report = rank_result[0]

    #rank_dict = ActiveRecord::Base.connection.select_all(sanitize_sql("select rank_identity as rank_id, name as rank_name from client_ranks"))
    #rank_report['qualified_rank_name_current']  = rank_report['qualified_rank_id_current'].blank? ? nil : rank_dict.select {|k,v| k['rank_id'] == rank_report['qualified_rank_id_current']}[0]['rank_name']
    #rank_report['qualified_rank_name_previous'] = rank_report['qualified_rank_id_previous'].blank? ? nil : rank_dict.select {|k,v| k['rank_id'] == rank_report['qualified_rank_id_previous']}[0]['rank_name']
    #rank_report['paid_rank_name_current']       = rank_report['paid_rank_id_current'].blank? ? nil : rank_dict.select {|k,v| k['rank_id'] == rank_report['paid_rank_id_current']}[0]['rank_name']
    #rank_report['paid_rank_name_previous']      = rank_report['paid_rank_id_previous'].blank? ? nil : rank_dict.select {|k,v| k['rank_id'] == rank_report['paid_rank_id_previous']}[0]['rank_name']
    #rank_report['lifetime_rank_name_current']   = rank_report['lifetime_rank_id_current'].blank? ? nil : rank_dict.select {|k,v| k['rank_id'] == rank_report['lifetime_rank_id_current']}[0]['rank_name']
    #rank_report['lifetime_rank_name_previous']  = rank_report['lifetime_rank_id_previous'].blank? ? nil : rank_dict.select {|k,v| k['rank_id'] == rank_report['lifetime_rank_id_previous']}[0]['rank_name']

#    rank_report['pvq_current'] = 0
#    rank_report['pvdt_current'] = 0
#    rank_report['pvu_current'] = 0
#    rank_report['order_info_current'].split(':').each do |order|
#      order_e = order.split(',')
#      unless order_e.nil? or order_e.empty?
##        rank_report['pvq_current'] += order_e[1].to_f
#        rank_report['pvdt_current'] += order_e[3].to_f
#        rank_report['pvu_current'] += order_e[4].to_f
#      end
#    end if !rank_report['order_info_current'].nil?

#    rank_report['pvq_previous'] = 0
#    rank_report['pvdt_previous'] = 0
#    rank_report['pvu_previous'] = 0
#    rank_report['order_info_previous'].split(':').each do |order|
#      order_e = order.split(',')
#      unless order_e.nil? or order_e.empty?
##        rank_report['pvq_previous'] += order_e[1].to_f
#        rank_report['pvdt_previous'] += order_e[3].to_f
#        rank_report['pvu_previous'] += order_e[4].to_f
#      end
#    end if !rank_report['order_info_previous'].nil?

    # TODO
    # because pvq include retail customer's pvq, and get_distributor_info_detail not yet support this feature
    # we use table rankdetails to get pvq
    # need to merget this into get_distributor_info_detail
#    pvq_curr_sql = "SELECT pvq from bonus.bonusm#{query_params[:start_date]}_rankdetails where distributor_id = #{query_params[:distributor_id]}"
#    pvq_curr_result = ActiveRecord::Base.connection.select_all(sanitize_sql(pvq_curr_sql))
#    pvq_prev_sql = "SELECT pvq from bonus.bonusm#{(query_params[:start_date].to_date << 1).strftime("%Y%m01")}_rankdetails where distributor_id = #{query_params[:distributor_id]}"
#    pvq_prev_result = ActiveRecord::Base.connection.select_all(sanitize_sql(pvq_prev_sql))
#    rank_report['pvq_current'] = pvq_curr_result.first['pvq']   if pvq_curr_result.present?
#    rank_report['pvq_previous'] = pvq_prev_result.first['pvq']   if pvq_prev_result.present?

      #sponsor_report_current = Distributor.left_right_leg_personally_sponsored_distributor_rank_hash(query_params)
      #rank_report['num_sponsored_current']                      = sponsor_report_current['num_sponsored']
#      rank_report['num_sponsored_rep_and_above_current']        = sponsor_report_current['num_sponsored_rep_and_above']
#      rank_report['num_sponsored_mas_and_above_current']        = sponsor_report_current['num_sponsored_mas_and_above']
#      rank_report['num_sponsored_rep_and_above_left_current']   = sponsor_report_current['num_sponsored_rep_and_above_left']
#      rank_report['num_sponsored_rep_and_above_right_current']  = sponsor_report_current['num_sponsored_rep_and_above_right']
#      rank_report['num_sponsored_con_and_above_left_current']   = sponsor_report_current['num_sponsored_con_and_above_left']
#      rank_report['num_sponsored_con_and_above_right_current']  = sponsor_report_current['num_sponsored_con_and_above_right']

      #query_params_prev = query_params.clone
      #query_params_prev[:start_date] = (query_params[:start_date].to_date  - 1.month).strftime("%Y-%m-%d")
      #sponsor_report_previous = Distributor.left_right_leg_personally_sponsored_distributor_rank_hash(query_params_prev)
      #rank_report['num_sponsored_previous']                      = sponsor_report_previous['num_sponsored']
#      rank_report['num_sponsored_rep_and_above_previous']        = sponsor_report_previous['num_sponsored_rep_and_above']
#      rank_report['num_sponsored_mas_and_above_previous']        = sponsor_report_previous['num_sponsored_mas_and_above']
#      rank_report['num_sponsored_rep_and_above_left_previous']   = sponsor_report_previous['num_sponsored_rep_and_above_left']
#      rank_report['num_sponsored_rep_and_above_right_previous']  = sponsor_report_previous['num_sponsored_rep_and_above_right']
#      rank_report['num_sponsored_con_and_above_left_previous']   = sponsor_report_previous['num_sponsored_con_and_above_left']
#      rank_report['num_sponsored_con_and_above_right_previous']  = sponsor_report_previous['num_sponsored_con_and_above_right']

    #dt_cluster_curr = Distributor.get_dualteam_view(query_params[:distributor_id],query_params[:start_date])
    #rank_report['num_sponsored_rep_and_above_left_current']   = Distributor.get_dualteam_view_count(dt_cluster_curr, 'L', 'REP')
    #rank_report['num_sponsored_rep_and_above_right_current']   = Distributor.get_dualteam_view_count(dt_cluster_curr, 'R', 'REP')
    #rank_report['num_sponsored_con_and_above_left_current']   = Distributor.get_dualteam_view_count(dt_cluster_curr, 'L', 'CON')
    #rank_report['num_sponsored_con_and_above_right_current']   = Distributor.get_dualteam_view_count(dt_cluster_curr, 'R', 'CON')
    #rank_report['num_sponsored_rep_and_above_current']        = rank_report['num_sponsored_rep_and_above_left_current'].to_i + rank_report['num_sponsored_rep_and_above_right_current'].to_i
    #rank_report['num_sponsored_mas_and_above_current']        = rank_report['num_sponsored_con_and_above_left_current'].to_i + rank_report['num_sponsored_con_and_above_right_current'].to_i
    #dt_cluster_prev = Distributor.get_dualteam_view(query_params_prev[:distributor_id],query_params_prev[:start_date])
    #rank_report['num_sponsored_rep_and_above_left_previous']   = Distributor.get_dualteam_view_count(dt_cluster_prev, 'L', 'REP')
    #rank_report['num_sponsored_rep_and_above_right_previous']   = Distributor.get_dualteam_view_count(dt_cluster_prev, 'R', 'REP')
    #rank_report['num_sponsored_con_and_above_left_previous']   = Distributor.get_dualteam_view_count(dt_cluster_prev, 'L', 'CON')
    #rank_report['num_sponsored_con_and_above_right_previous']   = Distributor.get_dualteam_view_count(dt_cluster_prev, 'R', 'CON')
    #rank_report['num_sponsored_rep_and_above_previous']        = rank_report['num_sponsored_rep_and_above_left_previous'].to_i + rank_report['num_sponsored_rep_and_above_right_previous'].to_i
    #rank_report['num_sponsored_mas_and_above_previous']        = rank_report['num_sponsored_con_and_above_left_previous'].to_i + rank_report['num_sponsored_con_and_above_right_previous'].to_i
      
    return rank_report   
#0      users_login character varying(255), 
#1      distributors_lifetime_rank int, 
#2      bill_adr_firstname character varying(255),  
#3      bill_adr_lastname character varying(255), 
#4      distributors_role_code character varying(255),  --CSV llist;  
#5      monthly_qualify character varying(255), 
#6      distributors_personal_sponsor_distributor_id bigint,  
#7      distributors_dualteam_sponsor_distributor_id bigint,  
#8      distributors_dualteam_current_position character varying(255),  
#9      distributors_dualteam_left_child bigint,  
#10     distributors_dualteam_right_child bigint, 
#11     users_entry_date timestamp, 
#12     distributors_next_renewal_date timestamp, 
#13     curr_m_b_id bigint,     --current month bonusmyyyymmdd
#14     curr_m_b_sponsor_id bigint, 
#15     curr_m_b_sponsor_id_dt bigint,  
#16     curr_m_b_lifetime_rank integer, 
#17     curr_m_b_lifetime_pvq numeric(10,2),  
#18     curr_m_b_prev_pvq numeric(10,2),  
#19     curr_m_b_order_info text, 
#20     curr_m_b_prev_pv_co_left_dt numeric(10,2),  
#21     curr_m_b_prev_pv_co_right_dt numeric(10,2), 
#22     curr_m_b_child_ids_ul text, 
#23     curr_m_b_left_child_id_dt bigint, 
#24     curr_m_b_right_child_id_dt bigint,  
#25     curr_m_b_join_prior_may_1st_2009 bit(1),  
#26     curr_m_b_pack_type integer, 
#27     curr_m_b_prev_rank integer, 
#28     curr_m_b_current_rank integer,  
#29     curr_m_b_paid_rank integer, 
#30     curr_m_b_unconditional_rank integer,  
#31     curr_m_b_conditional_rank integer,  
#32     curr_m_b_country_iso character varying(10), 
#33     curr_m_b_prior_pvqs character varying(255), 
#34     curr_w_b_id bigint,     --current week bonuswyyyymmdd,
#35     curr_w_b_sponsor_id bigint, 
#36     curr_w_b_sponsor_id_dt bigint,  
#37     curr_w_b_lifetime_rank integer, 
#38     curr_w_b_lifetime_pvq numeric(10,2),  
#39     curr_w_b_prev_pvq numeric(10,2),  
#40     curr_w_b_order_info text, 
#41     curr_w_b_prev_pv_co_left_dt numeric(10,2),  
#42     curr_w_b_prev_pv_co_right_dt numeric(10,2), 
#43     curr_w_b_child_ids_ul text, 
#44     curr_w_b_left_child_id_dt bigint, 
#45     curr_w_b_right_child_id_dt bigint,  
#46     curr_w_b_join_prior_may_1st_2009 bit(1),  
#47     curr_w_b_pack_type integer, 
#48     curr_w_b_prev_rank integer, 
#49     curr_w_b_current_rank integer,  
#50     curr_w_b_paid_rank integer, 
#51     curr_w_b_unconditional_rank integer,  
#52     curr_w_b_conditional_rank integer,  
#53     curr_w_b_country_iso character varying(10), 
#54     curr_w_b_prior_pvqs character varying(255), 
#55     curr_m_rd_distributor_id bigint,      --current month bonusmyyyymmdd_rankdetails
#56     curr_m_rd_prev_rank integer,  
#57     curr_m_rd_current_rank integer, 
#58     curr_m_rd_paid_rank integer,  
#59     curr_m_rd_pgv30 numeric(10,2),  
#60     curr_m_rd_pgv40 numeric(10,2),  
#61     curr_m_rd_active boolean, 
#62     curr_m_rd_pv_dt_sum_left numeric(10,2), 
#63     curr_m_rd_pv_dt_sum_right numeric(10,2),  
#64     curr_m_rd_pvq numeric(10,2),  
#65     curr_m_rd_pvq_rd numeric(10,2), 
#66     curr_m_rd_child_pgv_rd numeric(10,2), 
#67     curr_m_rd_child_pgv_rd_details text,  
#68     curr_w_dt_distributor_id bigint,      --current week bonuswyyyymmdd_dualteamdetails
#69     curr_w_dt_country_iso character varying(10),  
#70     curr_w_dt_bonus numeric(10,2),  
#71     curr_w_dt_bonus_percentage numeric(10,2), 
#72     curr_w_dt_paid_as_rank integer, 
#73     curr_w_dt_prev_pv_co_left numeric(20,2),  
#74     curr_w_dt_prev_pv_co_right numeric(20,2), 
#75     curr_w_dt_current_pv_co_left numeric(20,2), 
#76     curr_w_dt_current_pv_co_right numeric(20,2),  
#77     curr_w_dt_pv_left_sum numeric(20,2),  
#78     curr_w_dt_pv_right_sum numeric(20,2), 
#79     curr_w_dt_pvdt_bycountry text,  
#80     prev_m_b_id bigint,     --previous month bonusmyyyymmdd
#81     prev_m_b_sponsor_id bigint, 
#82     prev_m_b_sponsor_id_dt bigint,  
#83     prev_m_b_lifetime_rank integer, 
#84     prev_m_b_lifetime_pvq numeric(10,2),  
#85     prev_m_b_prev_pvq numeric(10,2),  
#86     prev_m_b_order_info text, 
#87     prev_m_b_prev_pv_co_left_dt numeric(10,2),  
#88     prev_m_b_prev_pv_co_right_dt numeric(10,2), 
#89     prev_m_b_child_ids_ul text, 
#90     prev_m_b_left_child_id_dt bigint, 
#91     prev_m_b_right_child_id_dt bigint,  
#92     prev_m_b_join_prior_may_1st_2009 bit(1),  
#93     prev_m_b_pack_type integer, 
#94     prev_m_b_prev_rank integer, 
#95     prev_m_b_current_rank integer,  
#96     prev_m_b_paid_rank integer, 
#97     prev_m_b_unconditional_rank integer,  
#98     prev_m_b_conditional_rank integer,  
#99     prev_m_b_country_iso character varying(10), 
#100      prev_m_b_prior_pvqs character varying(255), 
#101      prev_w_b_id bigint,     --previous week bonuswyyyymmdd,
#102      prev_w_b_sponsor_id bigint, 
#103      prev_w_b_sponsor_id_dt bigint,  
#104      prev_w_b_lifetime_rank integer, 
#105      prev_w_b_lifetime_pvq numeric(10,2),  
#106      prev_w_b_prev_pvq numeric(10,2),  
#107      prev_w_b_order_info text, 
#108      prev_w_b_prev_pv_co_left_dt numeric(10,2),  
#109      prev_w_b_prev_pv_co_right_dt numeric(10,2), 
#110      prev_w_b_child_ids_ul text, 
#111      prev_w_b_left_child_id_dt bigint, 
#112      prev_w_b_right_child_id_dt bigint,  
#113      prev_w_b_join_prior_may_1st_2009 bit(1),  
#114      prev_w_b_pack_type integer, 
#115      prev_w_b_prev_rank integer, 
#116      prev_w_b_current_rank integer,  
#117      prev_w_b_paid_rank integer, 
#118      prev_w_b_unconditional_rank integer,  
#119      prev_w_b_conditional_rank integer,  
#120      prev_w_b_country_iso character varying(10), 
#121      prev_w_b_prior_pvqs character varying(255), 
#122      prev_m_rd_distributor_id bigint,      --previous month bonusmyyyymmdd_rankdetails
#123      prev_m_rd_prev_rank integer,  
#124      prev_m_rd_current_rank integer, 
#125      prev_m_rd_paid_rank integer,  
#126      prev_m_rd_pgv30 numeric(10,2),  
#127      prev_m_rd_pgv40 numeric(10,2),  
#128      prev_m_rd_active boolean, 
#129      prev_m_rd_pv_dt_sum_left numeric(10,2), 
#130      prev_m_rd_pv_dt_sum_right numeric(10,2),  
#131      prev_m_rd_pvq numeric(10,2),  
#132      prev_m_rd_pvq_rd numeric(10,2), 
#133      prev_m_rd_child_pgv_rd numeric(10,2), 
#134      prev_m_rd_child_pgv_rd_details text,  
#135      prev_w_dt_distributor_id bigint,      --previous week bonuswyyyymmdd_dualteamdetails
#136      prev_w_dt_country_iso character varying(10),  
#137      prev_w_dt_bonus numeric(10,2),  
#138      prev_w_dt_bonus_percentage numeric(10,2), 
#139      prev_w_dt_paid_as_rank integer, 
#140      prev_w_dt_prev_pv_co_left numeric(20,2),  
#141      prev_w_dt_prev_pv_co_right numeric(20,2), 
#142      prev_w_dt_current_pv_co_left numeric(20,2), 
#143      prev_w_dt_current_pv_co_right numeric(20,2),  
#144      prev_w_dt_pv_left_sum numeric(20,2),  
#145      prev_w_dt_pv_right_sum numeric(20,2), 
#146      prev_w_dt_pvdt_bycountry text
  rescue
    logger.error("ERROR: distributor_id[#{query_params[:distributor_id]}] Commission::get_commissions_rank: #{table_name} table doesn't exist")
    return rank_report
  end

  ############################################################################
  def self.get_commissions_quarterly(query_params)
    return nil if query_params[:distributor_id].blank?

    sqlcmd = ""
    self.get_all_data_table_names('m').each do |table|
       period = table['relname'][-8,8]
       table_name = table['relname'] + '_globalpooldetails'
       if ActiveRecord::Base.connection.table_exists?("#{table_name}")
          sqlcmd += " UNION " if !sqlcmd.blank?
          sqlcmd += "SELECT extract(year from (date '#{period}')) as year, extract(quarter from (date '#{period}')) as quarter, extract(month from (date '#{period}')) as  month, * FROM bonus.#{table_name} WHERE distributor_id = #{query_params[:distributor_id]}"
       end
    end
   
    ActiveRecord::Base.connection.select_all(sanitize_sql(sqlcmd))
  end
  
  ############################################################################
  def self.get_ul_summary(query_params)
    commission_detail_table_name = Commission.formatted_monthly_data_table_name(query_params[:start_date]) + "_" + query_params[:commission_type] + "details"

    if not ActiveRecord::Base.connection.table_exists?(commission_detail_table_name)
      logger.error("ERROR: distributor_id[#{query_params[:distributor_id]}] Commission::get_ul_summary: #{commission_detail_table_name} table doesn't exist")
      return {}
    end

    #sql = %Q(select t5.iso as country_code,
    #                sum(bonus) as total_bonus,
    #                max(compressed_level) as total_compressed_levels,
    #                max(uncompressed_level) as total_uncompressed_levels,
    #                count(child_id) as total_children
    #          from #{commission_detail_table_name} t1,
    #               distributors t2,
    #              users t3,
    #              addresses t4,
    #              countries t5
    #          where t1.distributor_id = #{query_params[:distributor_id]} and
    #                t1.child_id = t2.id and
    #                t2.user_id = t3.id and
    #                t3.sold_address_id = t4.id and
    #                t4.country_id = t5.id
    #          group by t5.iso order by t5.iso;)

    sql = %Q(select sum(bonus) as total_bonus
              from #{commission_detail_table_name} t1
              where t1.distributor_id = #{query_params[:distributor_id]};)
    
    ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
  end
  
  ###########################################################################
  def self.get_weekly_select_option_dates
    self.get_select_option_dates(self.get_all_weekly_data_table_names, 'w')
  end
  
  ###########################################################################
  def self.get_monthly_select_option_dates
    self.get_select_option_dates(self.get_all_monthly_data_table_names, 'm')
  end
  
  ###########################################################################
  def self.get_quarterly_select_option_dates
    self.get_select_option_dates(self.get_all_monthly_data_table_names, 'm')
  end
  
  ###########################################################################
  def self.get_select_option_dates(data_table_names, commission_code)    
    # key: year; value: [date, internal_date]
    # hash[2011] = ['11/01', '20111101']
    hash = Hash.new {|h, k| h[k] = []}
    data_table_names.each do |data_table_name|
      name = data_table_name['relname']
      date = name[-8, 8].to_date
      if commission_code == 'm'   # monthly commission
        hash[date.year].push [date.strftime('%m/%d'), name[-8, 8]] if date >= COMMISSIONS_MONTLY_STARTDATE
      elsif commission_code == 'w'   # weekly commission
        date = date + 6.day          #get the date from DB, but display by adding 6 days, display the end of week (next friday)
        hash[date.year].push [date.strftime('%m/%d'), date.strftime('%Y%m%d')] if date >= COMMISSIONS_WEEKLY_STARTDATE
      elsif commission_code == 'r'   # rank 
        hash[date.year].push [date.strftime('%m/%d'), name[-8, 8]] if date >= COMMISSIONS_RANK_STARTDATE
      end
    end
    
    return hash
  end
  
  ############################################################################
  def self.get_all_weekly_data_table_names
    self.get_all_data_table_names('w')
  end
  
  ############################################################################
  def self.get_all_monthly_data_table_names
    self.get_all_data_table_names('m')
  end
  
  ############################################################################
  def self.get_all_data_table_names(period_code)
    sql = "SELECT relname 
           FROM pg_stat_user_tables 
           WHERE relname like '%bonus#{period_code}%' and 
                 (length(relname) = 14) and schemaname = 'bonus' 
           ORDER BY relname desc"
    ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
  end
    
  ############################################################################
  def self.monthly_start_date(selected_date)
    start_date(selected_date, 1)
  end 
  
  ############################################################################
  def self.quarterly_start_date(selected_date)
    start_date(selected_date, 1)
  end 
  
  ############################################################################
  def self.weekly_start_date(selected_date)
    start_date(selected_date, 2)
  end
  
  ############################################################################
  def self.start_date(selected_date, period_id)
    table_name = data_table_name(selected_date, period_id)

    # table name: bonus.bonusm20111101
    return table_name[-8,8]
  end    

  ############################################################################
  def self.monthly_data_table_name(selected_date)
    data_table_name(selected_date, 1)
  end

  ############################################################################
  def self.weekly_data_table_name(selected_date)
    data_table_name(select_date, 2)
  end

  ############################################################################
  def self.data_table_name(selected_date, period_id)
    sqlcmd = "select get_bonus_tablename('#{selected_date}', #{period_id})"
    response = ActiveRecord::Base.connection.select_all(sqlcmd)
    return response[0]['get_bonus_tablename']
  end
 
  ############################################################################
  def self.formatted_monthly_data_table_name(date)                                                                                                                                                           
    formatted_data_table_name(date, 'm')                                                                                                                                                                       
  end  

  ############################################################################
  def self.formatted_weekly_data_table_name(date)                                                                                                                                                           
    formatted_data_table_name(date, 'w')                                                                                                                                                                       
  end

  ############################################################################
  def self.formatted_data_table_name(date, period_code)                                                                                                                                                      
    "bonus.bonus#{period_code}#{date.gsub(/-/,'')}"                                                                                                                                                             
  end
  
  def self.italy_personal_data(param)
    date = param[:commission_date].to_date
    return [] if date.nil? || param.nil? || param[:distributor_ids].nil?
    commission_date = date
    distributor_ids = []
    param[:distributor_ids].each do |id|
      distributor_ids << id.to_i
    end
    return [] if distributor_ids.size < 1
    
    sqlcmd = "select
                   d.id,
                   ad.lastname,
                   ad.firstname,
                   ad.address1,
                   ad.zipcode,
                   ad.city,
                   s.name,
                   d.social_security_number,
                   d.taxnumber,
                   d.date_of_birth,
                   da.place_of_birth birth_place,
                   birth_states.name birth_province,
                   da.gender gender,
                   da.business_date_register vat_reg_date,
                   da.business_date_cancel vat_cancel_date,
                   da.social_security_type social_security_type,
                   null prefix,
                   ad.phone,
                   null as mobile_prefix,
                   ad.mobile_phone,
                   u.email
               from users u, addresses ad, states s, distributors d
                   left join distributor_addons da on (da.distributor_id = d.id)
                   left join states birth_states on (birth_states.id = da.state_id_birth)
               where u.id = d.user_id and ad.id = u.sold_address_id and s.id = ad.state_id and d.id in (#{distributor_ids.join(',')})"

    ActiveRecord::Base.connection.select_all(sanitize_sql(sqlcmd))
  end

  def self.italy_commission_movement(params)
    commission_date = params[:commission_date]
    commission_type  = params[:commission_type]
    
    return [[], []] if commission_date.nil? or commission_type.nil?

    italy_commission_movement =[]
    distributors_list = []
    query_params = {}
    date = commission_date.to_date
    query_params[:start_date] = (date - date.strftime("%u").to_i + 1).to_date.strftime("%Y-%m-%d")
    query_params[:country_iso] = 'IT'
    query_params[:limit] = 'null'
    query_params[:offset] = 'null'
    if commission_type == "month"
      month_date = date.strftime("%Y-%m-01")
       sqlcmd = "select bm.distributor_id,
                        bm.country_home,
                        d.social_security_number,
                        COALESCE(earning_ul_local,0) + COALESCE(earning_ulmatch_local,0) + COALESCE(earning_generation_local,0) as commission
                 from get_commissions_month('#{month_date.to_date.strftime("%Y%m%d")}',null,null) bm, distributors d, users u, addresses ad
                 where bm.distributor_id = d.id and d.user_id = u.id and u.sold_address_id = ad.id and ad.country_id = 1098"
      begin
        ActiveRecord::Base.connection.select_all(sanitize_sql(sqlcmd)).each do |dist_form|
          hash_rec = {}
          hash_rec['distributor_id'] = dist_form['distributor_id']
          hash_rec['social_security_number'] = dist_form['social_security_number']
          hash_rec['commission'] = dist_form['commission']
          italy_commission_movement << hash_rec
          distributors_list << dist_form['distributor_id']
        end
      rescue
         return [[], []] 
      end
    end
    if commission_type == "week"
      begin
        Commission.get_commissions_week(query_params).each do |dist_form|
          hash_rec = {}
          hash_rec['distributor_id'] = dist_form['distributor_id']
          hash_rec['social_security_number'] = dist_form['social_security_number']
          hash_rec['commission'] = dist_form['earning_dualteam_local'].to_f + dist_form['earning_fasttrack_local'].to_f + dist_form['earning_retail_local'].to_f
          italy_commission_movement << hash_rec
          distributors_list << dist_form['distributor_id']
        end
      rescue
        return [[], []]
      end
    end    
    return [distributors_list, italy_commission_movement]
  end
  
  def self.commission_tables(start_date, end_date)
    s = start_date.to_date.strftime("%Y%m%d")
    e = end_date.to_date.strftime("%Y%m%d")
    sql = "select relname from pg_stat_user_tables where schemaname='bonus' and ((relname >= 'bonusm#{s}_a' and relname < 'bonusm#{e}_z') or (relname >= 'bonusw#{s}_a' and relname < 'bonusw#{e}_z')) order by relname asc;"
    ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
  end

  def self.all_datas_in_one_table(start_date, end_date, distributor_id)
    all_datas = {
      :week => {},
      :month => {},
      :quarter => {}
    }

    table_names = Commission.commission_tables(start_date, end_date)
    table_names.each do |line|
      name = line["relname"].to_s
      next if name[0..5] != "bonusm" && name[0..5] != "bonusw"
      table_date = name[6..13].to_date
      date = table_date.strftime("%Y-%m-%d")

      type, type_index = Commission.get_table_type(name)
      next if type.blank?
      next if type_index == :week && table_date.cwday != 1

      if all_datas[type_index][date].nil?
        all_datas[type_index][date] = {:paid_rank => "", :datas => []}
        if type_index == :month || type_index == :quarter
          all_datas[type_index][date][:paid_rank] = Commission.get_month_bonus_paid_rank(name[6..13], distributor_id)
        end
      end 
      datas = Commission.get_table_datas(name, distributor_id, type_index)
      if datas.present?
        datas.each do |data|
          data['type'] = type
        end
        all_datas[type_index][date][:paid_rank] = datas.first['paid_rank'] if type_index == :week && type == "Dual Team"
        all_datas[type_index][date][:datas] += datas
      end
    end
    all_datas
  end

  def self.get_table_type(name)
    type = ""
    type_index = ""
    if name.end_with?("dualteamdetails")
      type = "Dual Team"
      type_index = :week
    elsif name.end_with?("fasttracktotal")
      type = "Fast Track"
      type_index = :week
    elsif name.end_with?("retailtotal")
      type = "Retail"
      type_index = :week
    elsif name.end_with?("unileveldetails")
      type = "Unilevel"
      type_index = :month
    elsif name.end_with?("unilevelmatchdetails")
      type = "Unilevel Match"
      type_index = :month
    elsif name.end_with?("generationdetails")
      type = "Generation"
      type_index = :month
    elsif name.end_with?("globalpooldetails")
      type = "Global Pool"
      type_index = :quarter
    end
    [type, type_index]
  end

  def self.get_table_datas(name, distributor_id, type_sym)
    datas = []
    if type_sym == :week
      datas = Commission.get_week_bonus_datas(name, distributor_id)
    elsif type_sym == :month
      datas = Commission.get_month_bonus_datas(name, distributor_id)
    elsif type_sym == :quarter
      datas = Commission.get_quarter_bonus_datas(name, distributor_id)
    end
    datas
  end
  
  # def self.sum_bonus(table_name, distributor_id)
  #   sql = "SELECT 
  #     bonus.#{table_name}.distributor_id as distributor_id, 
  #     bonus.#{table_name}.bonus as bonus, 
  #     bonus.#{table_name}.paid_as_rank as paid_rank,
  #     client_fxrates.convert_rate as rate,
  #     (bonus.#{table_name}.bonus * client_fxrates.convert_rate) as local_bonus,
  #     countries.iso as country_iso
      
  #     FROM bonus.#{table_name}
  #     left join distributors on (bonus.#{table_name}.distributor_id = distributors.id)
  #     left join users on (distributors.user_id = users.id)
  #     left join addresses on (users.sold_address_id = addresses.id)
  #     left join countries on (addresses.country_id = countries.id)
  #     left join client_fxrates on (countries.currency_id = client_fxrates.currency_id)
    
  #     where bonus.#{table_name}.distributor_id = #{distributor_id} ;"
  #   ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
  # end


  # week
  # dualteam amount is USD(149)
  # fasttrack and retail need to include currency_id
  # fasttrack amount is EUR(49) or USD(149)
  # retail amount is currency_id
  def self.build_week_bonus_sql_select(table_name)
    if table_name.end_with?("dualteamdetails")
      week_table_name = table_name.split("_").first
      " 
        bonus.#{table_name}.distributor_id as distributor_id,
        bonus.#{table_name}.bonus as amount, 
        bonus.#{week_table_name}.paid_rank as paid_rank,
        bonus.#{table_name}.country_iso as country_iso
      "
    elsif table_name.end_with?("fasttracktotal")
      "
        bonus.#{table_name}.distributor_id as distributor_id,
        (bonus.#{table_name}.fasttrack_volume - bonus.#{table_name}.fasttrack_volume_reverse) as amount,
        bonus.#{table_name}.order_country as country_iso,
        bonus.#{table_name}.currency_id as fasttrack_currency_id,
        bonus.#{table_name}.currency_iso as fasttrack_currency_iso,
        bonus.#{table_name}.currency_id as currency_id,
        bonus.#{table_name}.currency_iso as currency_iso
      "
    elsif table_name.end_with?("retailtotal")
      "
        bonus.#{table_name}.distributor_id as distributor_id,
        (bonus.#{table_name}.item_total - bonus.#{table_name}.wholesale_total - (bonus.#{table_name}.item_total_reverse - bonus.#{table_name}.wholesale_total_reverse)) as amount,
        bonus.#{table_name}.order_country as country_iso,
        bonus.#{table_name}.currency_id as currency_id,
        bonus.#{table_name}.currency_iso as currency_iso
      "
    else
      ""
    end
  end

  def self.get_week_bonus_datas(table_name, distributor_id)
    sql = "select "
    select = build_week_bonus_sql_select(table_name)
    return [] if select.blank?
    sql += select
    sql += " from bonus.#{table_name} "
    if table_name.end_with?("dualteamdetails")
      week_table_name = table_name.split("_").first
      sql += " join bonus.#{week_table_name} on bonus.#{week_table_name}.id = bonus.#{table_name}.distributor_id "
    end
    sql += " where bonus.#{table_name}.distributor_id = #{distributor_id} ;"
    ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
  end

  def self.get_month_bonus_paid_rank(date, distributor_id)
    table_name = "bonusm#{date}_rankdetails"
    sql = "select paid_rank from bonus.#{table_name} where distributor_id = #{distributor_id};"
    datas = (ActiveRecord::Base.connection.select_all(sanitize_sql(sql)) rescue [])
    datas.present? ? datas.first['paid_rank'] : ""
  end

  # month amount is USD(149)
  def self.get_month_bonus_datas(table_name, distributor_id)
    sql = "select 
      bonus.#{table_name}.distributor_id as distributor_id,
      sum(bonus.#{table_name}.bonus) as amount 
      from bonus.#{table_name}
      where bonus.#{table_name}.distributor_id = #{distributor_id} 
      group by bonus.#{table_name}.distributor_id ;"
    ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
  end

  # quarter amount is USD(149)
  def self.get_quarter_bonus_datas(table_name, distributor_id)
    sql = " select 
      bonus.#{table_name}.distributor_id as distributor_id,
      sum(bonus.#{table_name}.bonus) as amount,
      bonus.#{table_name}.pool_rank as pool_rank
      from bonus.#{table_name}
      where bonus.#{table_name}.distributor_id = #{distributor_id}
      group by bonus.#{table_name}.distributor_id, bonus.#{table_name}.pool_rank
      order by bonus.#{table_name}.pool_rank asc
    "
    ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
  end

  def self.get_bonus_fxrate_hash(distributor_id)
    sql = "select 
      distributors.id as distributor_id,
      countries.iso as country_iso,
      currencies.id as currency_id,
      currencies.symbol as currency_symbol,
      client_fxrates.convert_rate as convert_rate
      from distributors
      left join users on users.id = distributors.user_id
      left join addresses on users.sold_address_id = addresses.id
      left join countries on countries.id = addresses.country_id
      left join currencies on countries.commission_currency_id = currencies.id
      left join client_fxrates on client_fxrates.currency_id = currencies.id
      where distributors.id = #{distributor_id};"
    ActiveRecord::Base.connection.select_all(sanitize_sql(sql)).first
  end

  def self.rank_advancement_report(period, trigger_rank_id, country_id = nil)
    period_current_month = period.to_date
    # trigger_rank_id ex: 80 rank id such as SAP
    # period  ex: 20120601 always beginning of the month
    if false
#    if period_current_month < '2012-09-01'.to_date
      prev_bonusm_table_date = period.to_date.prev_month.strftime("%Y%m%d")
        sql = "select 
              distinct d.id as distributor_id,
              ad.firstname || ' ' || ad.lastname account_name,
              ad.joint_firstname || ' ' || ad.joint_lastname joint_name,
              du.lifetime_rank_old previous_rank_id,
              cr_prev.name previous_rank_name,
              du.lifetime_rank_new current_rank_id,
              cr_curr.name current_rank_name,
              ad.country_id as country_id
           from
              distributor_update_logs du, distributors d, users u, addresses ad, bonus.bonusm#{period}_rankdetails br_curr, bonus.bonusm#{prev_bonusm_table_date}_rankdetails br_prev, client_ranks cr_prev, client_ranks cr_curr
           where 
              d.id = du.id_new and d.user_id = u.id and u.sold_address_id = ad.id and du.id_new = br_curr.distributor_id and br_curr.distributor_id = br_prev.distributor_id and cr_prev.rank_identity = du.lifetime_rank_old and cr_curr.rank_identity = du.lifetime_rank_new and br_curr.paid_rank >= #{trigger_rank_id} and br_curr.paid_rank >= br_prev.paid_rank and du.created_at >= '#{period.to_date.strftime("%Y-%m-%d")}' and du.created_at < '#{period.to_date.next_month.strftime("%Y-%m-01")}' and du.lifetime_rank_new > du.lifetime_rank_old and du.lifetime_rank_new >= br_curr.paid_rank "
      if country_id.present?
        sql += " and ad.country_id = #{country_id} "
      end
    
      sql += " order by d.id;"
    else
      sql_country_id = country_id.present? ? country_id : "NULL"
      sql = "SELECT
            rank.distributor_id AS distributor_id, 
            rank.account_name AS account_name, 
            rank.joint_name AS joint_name, 
            rank.previous_rank_id AS previous_rank_id, 
            rank.current_rank_id AS current_rank_id, 
            rank.current_rank_name AS current_rank_name, 
            rank.country_id AS country_id,
            addresses.address1 AS address1,
            addresses.address2 AS address2,
            addresses.city AS city,
            addresses.zipcode AS zipcode,
            states.abbr AS state,
            countries.iso AS country
            FROM get_rank_advance(#{trigger_rank_id}, '#{period_current_month.strftime("%Y%m01")}', #{sql_country_id}, NULL) AS rank
            LEFT JOIN distributors ON distributors.id = distributor_id
            LEFT JOIN users ON users.id = distributors.user_id
            LEFT JOIN addresses ON addresses.id = users.sold_address_id
            LEFT JOIN countries ON countries.id = addresses.country_id
            LEFT JOIN states ON states.id = addresses.state_id
            ORDER BY distributor_id"
      # sql = "select * from get_rank_advance(#{trigger_rank_id}, '#{period_current_month.strftime("%Y%m01")}', #{sql_country_id}, NULL) order by distributor_id"
    end
    ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
  end
  
  def self.team_flashlights(rank_id, date, distributor_id, country_id = nil)
    
    country_id ||= 'NULL'
    sqlcmd = "select * from get_rank_advance(#{rank_id}, '#{date}', #{country_id}, #{distributor_id}) order by current_rank_id desc "
    
    key = "#{rank_id.to_s}_#{date.to_s}_#{distributor_id.to_s}_#{country_id.to_s}_team_flashlights"
    begin
      team_flashlights = Couch.client_community.get(key)
    rescue Exception => ex
      logger.error("ERROR: Coummity::team_flashlights, Couch.client_community.get(),  #{ex.to_s}")
      team_flashlights = nil
    end
    
    begin
      if team_flashlights.nil?
        team_flashlights = ActiveRecord::Base.connection.select_all(sanitize_sql(sqlcmd))
        Couch.client_genealogy.set(key, team_flashlights, :ttl => 7200)
      end
    rescue Couchbase::Error::Connect => ex
      logger.error("ERROR: Coummity::team_flashlights, Couch.client_community.set(), #{ex.to_s}")
    rescue Exception => ex
      logger.error("ERROR: Coummity::team_flashlights, #{ex.to_s}") 
    end
    
    team_flashlights.nil? ?  [] : team_flashlights
  end

  def self.star_rewards_report(date = nil, distributor_id = nil)
    sql = "SELECT d.id, d.company, ad.firstname, ad.lastname, 
                  coalesce(ad.firstname, '') || coalesce(' ' || ad.lastname, '') AS name,
                  coalesce(ad.joint_firstname, '') || coalesce(' ' || ad.joint_lastname, '') AS joint_name,
                  cn.iso country, ad.address1, ad.city, st.abbr state_name, ad.zipcode, u.email, 
                  dg.current_month as period, dg.month_count_ge_450 period_star_count, dg.is_superstar, 
                  dg.children_ge_450 as children_ids, array_length(dg.children_ge_450, 1) as count 
          FROM distributors d, distributor_ge_450 dg, users u, addresses ad, countries cn, states st 
          WHERE d.id = dg.distributor_id and u.id = d.user_id and u.sold_address_id = ad.id and 
                ad.country_id = cn.id and st.id = ad.state_id "
    sql += " and dg.current_month = '#{date}' " if date.present?
    sql += " and d.id = #{distributor_id} " if distributor_id.present?
    sql += " ORDER BY d.id"
    ActiveRecord::Base.connection.select_all(sql)
  end

  #@param[start_date]  20140301
  def self.get_commissions_monthly_summary(opts = {})
    summary = {}
    commission_type = [:unilevel, :leadershippool, :lifestype, :generationalmatch]

    unless opts[:start_date]
      opts[:start_date] = Commission.get_all_monthly_data_table_names.first.values[0][-8..-1]
    end
    table_name_prefix = Commission.formatted_monthly_data_table_name(opts[:start_date])
    commission_type.each do |ct|
      table_name = "#{table_name_prefix}_#{ct}details"
      if ActiveRecord::Base.connection.table_exists?(table_name)
        sql    = "select sum(bonus) as total from #{table_name} where bonus > 0;"
        result = ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
        summary[ct] = result[0]['total'].to_f
      else
        summary[ct] = 0
      end
    end
    summary
  end

  def self.get_commissions_weekly_summary(opts = {})
    summary = {}
    unless opts[:start_date]
      weekly_dates      = Commission.get_weekly_select_option_dates
      opts[:start_date] = weekly_dates[weekly_dates.first[0]][0][1]
    end

    real_date  = Commission.weekly_start_date(opts[:start_date])
    table_name = "#{Commission.formatted_weekly_data_table_name(real_date)}_dualteamdetails"
    if ActiveRecord::Base.connection.table_exists?(table_name)
      sql    = "select sum(bonus) as total from #{table_name} where bonus > 0;"
      result = ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
      summary[:dualteam] = result[0]['total'].to_f
    else
      summary[:dualteam] = 0
    end

    summary
  end

  def self.get_commissions_weekly_bonus_detail(opts = {})
    result = []
    unless opts[:start_date]
      weekly_dates      = Commission.get_weekly_select_option_dates
      opts[:start_date] = weekly_dates[weekly_dates.first[0]][0][1]
    end

    real_date  = Commission.weekly_start_date(opts[:start_date])
    table_name = "#{Commission.formatted_weekly_data_table_name(real_date)}_dualteamdetails"
    if ActiveRecord::Base.connection.table_exists?(table_name)
      sql    = "select distributor_id, sum(bonus) as total from #{table_name} where bonus > 0 group by distributor_id order by distributor_id;"
      rrr    = ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
      unless rrr.empty?
        rrr.each do |r|
          name = ::Distributor.find(r['distributor_id']).user.name rescue nil
          result << {distributor_id: r['distributor_id'],name: name, total: r['total']}
        end
      end
    end
    result
  end

  def self.get_commissions_weekly_match_profits(opts = {})
    result = []
    unless opts[:start_date]
      weekly_dates      = Commission.get_weekly_select_option_dates
      opts[:start_date] = weekly_dates[weekly_dates.first[0]][0][1]
    end

    real_date  = Commission.weekly_start_date(opts[:start_date])
    table_name = "#{Commission.formatted_weekly_data_table_name(real_date)}_doubleteammatchprofits"
    if ActiveRecord::Base.connection.table_exists?(table_name)
      sql    = "select distributor_id, double_team_match_profit from #{table_name};"
      rrr    = ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
      unless rrr.empty?
        rrr.each do |r|
          result << {distributor_id: r['distributor_id'], match_profits: r['double_team_match_profit']}
        end
      end
    end
    result
  end

  #@param[start_date]  20140301
  #@params[table_tail] unilevel || generationalmatch
  def self.get_commissions_month_bonus_info(opts = {})
    result = []

    unless opts[:start_date]
      opts[:start_date] = Commission.get_all_monthly_data_table_names.first.values[0][-8..-1]
    end

    table_name_prefix = Commission.formatted_monthly_data_table_name(opts[:start_date])
    table_name        = "#{table_name_prefix}_#{opts[:table_tail]}details"

    if ActiveRecord::Base.connection.table_exists?(table_name)
      sql    = "select distributor_id, sum(bonus) as total from #{table_name} where bonus > 0 group by distributor_id order by distributor_id;"
      rrr    = ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
      unless rrr.empty?
        rrr.each do |r|
          name = ::Distributor.find(r['distributor_id']).user.name rescue nil
          result << {distributor_id: r['distributor_id'],name: name, total: r['total']}
        end
      end
    end
    result
  end

  #@param[start_date] 20140401
  #@param[distributor_id]
  #@param[type]
  def self.get_commissions_month_detail_info(opts = {})
    unless opts[:start_date]
      opts[:start_date] = Commission.get_all_monthly_data_table_names.first.values[0][-8..-1]
    end

    case opts[:type]
    when 'unilevel'          then get_bonus_unileveldetails(opts)
    when 'generationalmatch' then get_bonus_generationalmatchdetails(opts)
    else
      []
    end
  end

  #@param[start_date] 20140401
  #@param[distributor_id]
  def self.get_bonus_unileveldetails(opts = {})
    result     = []
    table_name = "#{Commission.formatted_monthly_data_table_name(opts[:start_date])}_unileveldetails"
    if ActiveRecord::Base.connection.table_exists?(table_name)
      sql = "select * from #{table_name} where distributor_id = #{opts[:distributor_id]} and bonus > 0 order by bonus_level;"
      rrr = ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
      unless rrr.empty?
        rrr.each do |r|

          orders_info = []
          r['child_order_info'].split(':').each do |order|
            order_info = order.split('|')
            orders_info << {number: order_info[0], pv: order_info[4]}
          end

          result << {
            bonus:          r['bonus'],
            child_id:       r['child_id'],
            bonus_level:    r['bonus_level'],
            total_child_pv: r['child_pv_ul'],
            multiplier:     r['multiplier'],
            order_info:     orders_info
          }
        end
      end
    end
    result
  end


  def self.get_bonus_generationalmatchdetails(opts = {})
    result     = []
    table_name = "#{Commission.formatted_monthly_data_table_name(opts[:start_date])}_generationalmatchdetails"

    if ActiveRecord::Base.connection.table_exists?(table_name)
      sql = "select * from #{table_name} where distributor_id = #{opts[:distributor_id]};"
      rrr = ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
      unless rrr.empty?
        rrr.each do |r|
          result << {
            bonus:           r['bonus'],
            child_id:        r['child_id'],
            bonus_level:     r['bonus_level'],
            child_mob_bonus: r['member_unilevel_bonus'],
            multiplier:      r['multiplier']
          }
        end
      end
    end
    result
  end

end
