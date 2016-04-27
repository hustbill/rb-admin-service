module UsersHelper

  def sort_column
    case params[:sort]
    #when 'column name in search params'
        #'column instance', see app/models/user.rb: self.usersql()
    when 'login'
      'u.login'
    when 'entry-date'
      'u.entry_date'
    when 'distributor-id'
      'd.id'
    when 'name'
      'user_name'
    when 'sponsor-name'
      'sponsor_name'
    when 'role'
      'role'
    else
      'd.id'
    end
  end

  def sort_direction_fix
    case params[:direction]
    when 'asc'
      'asc'
    when 'desc'
      'desc'
    else
      'desc'
    end
  end

  def search_fix
    where  = " WHERE d.id is not null AND u.status_id = 1 "

    if params['is_expired'].present?
      if params['is_expired'] == 'expired'
        where += " AND (r.role_code = 'D' and (d.next_renewal_date is null or d.next_renewal_date < '#{Time.now.to_date}'))"
      else
        where += " AND (r.role_code = 'D' and (d.next_renewal_date is not null and d.next_renewal_date >= '#{Time.now.to_date}'))"
      end
    end
    acc_search_fix(where, params)
  end

  def terminate_search_fix
    where  = " WHERE d.id is not null AND u.status_id = 6 "
    acc_search_fix(where, params)
  end

  def inactive_search_fix
    where  = ' WHERE d.id is not null AND u.status_id != 1 '
    acc_search_fix(where, params)
  end

  def expired_search_fix
    expired_day = params[:expired_day].to_i
    if expired_day > 0
      sql = "AND (r.role_code = 'D' and ('#{Time.now}'::Date - d.next_renewal_date::Date >= #{expired_day}))"
    else
      sql = "AND (r.role_code = 'D' and (d.next_renewal_date is null or d.next_renewal_date < '#{Time.now.to_date}'))"
    end
    where = " WHERE d.id is not null AND u.status_id = 1 #{sql}"
    acc_search_fix(where, params)
  end

  def numeric? (s)
    Float(s) != nil rescue false
  end

  def acc_search_fix(where, params = {})
    # where += " AND column_instance = column name in search params" if(this param exists and in correct format), see app/models/user.rb: self.usersql()
    where += " AND LOWER(r.name) like LOWER(\'%#{params['role']}%\')" if params['role'].present?
    where += " AND u.status_id = #{params['status_id']}" if params['status_id'].to_i > 0
    where += " AND c.id = #{params['country_id']}" if params['country_id'].present?
    where += " AND add.state_id = #{params['state_id']}" if params['state_id'].to_i > 0
    where += " AND d.id = #{params['id_or_login']}" if params['id_or_login'] and numeric?(params['id_or_login'])
    where += " AND LOWER(u.login) like LOWER(\'%#{params['id_or_login']}%\')" if params['id_or_login'].present? and !numeric?(params['id_or_login'])
    where += " AND d.id = #{params['distributor_id']}" if params['distributor_id'].present? and numeric?(params['distributor_id'])
    where += " AND LOWER(u.login) like LOWER(\'%#{params['login']}%\')" if params['login'].present?
    where += " AND LOWER(u.email) like LOWER(\'%#{params['email']}%\')" if params['email'].present?
    where += " AND LOWER(add.phone) like LOWER(\'%#{params['phone']}%\')" if params['phone'].present?
    where += " AND LOWER(d.taxnumber) like LOWER(\'%#{params['taxnumber']}%\')" if params['taxnumber'] and numeric?(params['taxnumber'])
    where += " AND LOWER(add.lastname) like LOWER(\'%#{params['lastname']}%\')" if params['lastname'].present?
    where += " AND LOWER(add.firstname) like LOWER(\'%#{params['firstname']}%\')" if params['firstname'].present?
    where += " AND LOWER(add_sponsor.lastname) like LOWER(\'%#{params['sponsor_lastname']}%\')" if params['sponsor_lastname'].present?
    where += " AND LOWER(add_sponsor.firstname) like LOWER(\'%#{params['sponsor_firstname']}%\')" if params['sponsor_firstname'].present?
    where += " AND LOWER(add.joint_lastname) like LOWER(\'%#{params['joint_lastname']}%\')" if params['joint_lastname'].present?
    where += " AND LOWER(add.joint_firstname) like LOWER(\'%#{params['joint_firstname']}%\')" if params['joint_firstname'].present?
    where += " AND date_part('month', d.date_of_birth) = #{params['birthday']}" if params['birthday'].present?
    where
  end


end
