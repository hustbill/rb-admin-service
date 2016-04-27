class CommissionAdjustment < ActiveRecord::Base

  def self.create_or_update(params)
    search_date = "#{params[:year]}#{params[:date]}"
    date = search_date.to_date.strftime("%Y%m01")
    id = params[:distributor_id]
    commission = params[:amount].to_f
    details = '\'["' + params[:note] + '"]\''

    sql_check = "select * from pg_tables where schemaname = 'bonus' and tablename = 'bonusm#{date}_manual_commissions'"
    sql_create = "create table bonus.bonusm#{date}_manual_commissions (commission_type_id int not null, distributor_id int not null, commission numeric(18,2), overview text, details text, primary key(distributor_id, commission_type_id))"
    sql_find = "select * from bonus.bonusm#{date}_manual_commissions where distributor_id = #{id} and commission_type_id = (select id from commission_types where code = 'ADJ')"
    sql_update = "update bonus.bonusm#{date}_manual_commissions set commission = #{commission}, details = #{details} where distributor_id = #{id} and commission_type_id = (select id from commission_types where code = 'ADJ')"
    sql_insert = "insert into bonus.bonusm#{date}_manual_commissions (commission_type_id, distributor_id, commission, details, overview) values ((select id from commission_types where code = 'ADJ'), #{id}, #{commission}, #{details}, \'[]\')"

    res = ActiveRecord::Base.connection.select_all(sanitize_sql(sql_check))
    if res.count == 0
      ActiveRecord::Base.connection.execute(sanitize_sql(sql_create))
    end

    res = ActiveRecord::Base.connection.select_all(sanitize_sql(sql_find))
    if res.count > 0
      ActiveRecord::Base.connection.execute(sanitize_sql(sql_update))
    else
      ActiveRecord::Base.connection.execute(sanitize_sql(sql_insert))
    end
  end

  def self.create_commission_or_update(params)
    search_date = "#{params[:year]}#{params[:date]}"
    date = search_date.to_date.strftime("%Y%m01")
    id = params[:distributor_id]
    commission = params[:amount].to_f
    details = '\'["' + params[:note] + '"]\''

    sql_check = "select * from pg_tables where schemaname = 'bonus' and tablename = 'bonusm#{date}_commissions'"
    sql_create = "create table bonus.bonusm#{date}_commissions (commission_type_id int not null, distributor_id int not null, commission numeric(18,2), overview text, details text, primary key(distributor_id, commission_type_id))"
    sql_find = "select * from bonus.bonusm#{date}_commissions where distributor_id = #{id} and commission_type_id = (select id from commission_types where code = 'ADJ')"
    sql_update = "update bonus.bonusm#{date}_commissions set commission = #{commission}, details = #{details} where distributor_id = #{id} and commission_type_id = (select id from commission_types where code = 'ADJ')"
    sql_insert = "insert into bonus.bonusm#{date}_commissions (commission_type_id, distributor_id, commission, details, overview) values ((select id from commission_types where code = 'ADJ'), #{id}, #{commission}, #{details}, \'[]\')"
    res = ActiveRecord::Base.connection.select_all(sanitize_sql(sql_check))
    if res.count == 0
      ActiveRecord::Base.connection.execute(sanitize_sql(sql_create))
    end

    res = ActiveRecord::Base.connection.select_all(sanitize_sql(sql_find))
    if res.count > 0
      ActiveRecord::Base.connection.execute(sanitize_sql(sql_update))
    else
      ActiveRecord::Base.connection.execute(sanitize_sql(sql_insert))
    end
  end

  def self.find_all(params)
    params[:date] = Time.now.strftime("%Y-%m-%d") if params[:date].blank?
    if params[:date].blank?
      search_date = Time.now.strftime("%Y-%m-%d")
    else
      search_date = "#{params[:year]}#{params[:date]}"
    end
    date = search_date.to_date.strftime("%Y%m01")
    id_search = params[:id].blank? ? "" : "and d.id = #{params[:id]}"
    country = params[:country_id].blank? ? "" : "and add.country_id = #{params[:country_id]}"
    check = "select * from pg_tables where schemaname = 'bonus' and tablename = 'bonusm#{date}_manual_commissions'"
    create = "create table bonus.bonusm#{date}_manual_commissions (commission_type_id int not null, distributor_id int not null, commission numeric(18,2), overview text, details text, primary key(distributor_id, commission_type_id))"
    sql = "
           select d.id,
                  sum(c1.commission),
                  c2.commission as adj,
                  c2.details as note,
                  add.lastname,
                  add.firstname
             from users_home_addresses uha,
                  addresses add,
                  distributors d
        left join bonus.bonusm#{date}_commissions c1
               on d.id = c1.distributor_id
              and c1.commission_type_id != (select id from commission_types where code = 'ADJ')
        left join bonus.bonusm#{date}_manual_commissions c2
               on d.id = c2.distributor_id
              and c2.commission_type_id = (select id from commission_types where code = 'ADJ')
            where d.user_id = uha.user_id
              and add.id = uha.address_id
              and uha.is_default = true
              and uha.active = true
                #{id_search} #{country}
         group by d.id, add.firstname, add.lastname, c2.commission, c2.details
           having sum(c1.commission) > 0
         order by d.id
          "
    res = ActiveRecord::Base.connection.select_all(sanitize_sql(check))
    if res.count == 0
      ActiveRecord::Base.connection.execute(sanitize_sql(create))
    end
    ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
  end

end