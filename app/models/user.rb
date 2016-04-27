class User < ActiveRecord::Base

  has_one :distributor
  has_and_belongs_to_many :roles
  has_many :users_home_addresses
  belongs_to :entry_user, :class_name => "User", :foreign_key => "entry_operator"
  has_many :addresses, :through => :users_home_addresses
  has_one :one_users_home_address,->{ where(is_default: true) }, :class_name =>'UsersHomeAddress'
  has_one :one_home_address, :class_name => 'Address', :through => :one_users_home_address, :source => 'address'
  belongs_to :status
  has_many   :user_tracks
  has_many :admin_notes, as: :source
  has_many :operators, class_name: 'AdminNote', foreign_key: 'user_id'
  after_update :update_user_role_change

  scope :sortable, -> (column, direction) { order("#{column} #{direction}") }

  def decorated_attributes
    attrs = default_decorated_attributes
    attrs.merge!(distributor_customer_id) if CompanyConfig::CONFIG["enable_customer_id"]
    attrs
  end

  def default_decorated_attributes
    dha = default_home_address
    {
      "id"    => self.id,
      "email" => self.email,
      "login" => self.login,
      "taxnumber"      => (distributor.taxnumber rescue nil),
      "role"           => roles.map(&:name).join(','),
      "role-code"      => roles.map(&:role_code),
      "entry-date"     => self.entry_date,
      "entry-by"       => self.entry_by,
      "status-id"      => self.status_id,
      "status-name"    => (self.status.name rescue nil),
      "distributor-id" => (distributor.id rescue nil),
      "next-renewal-date" => (distributor.next_renewal_date.to_date rescue nil),
      "sponsor-id"      => (distributor.sponsor_distributor.id rescue nil),
      "sponsor-name"      => (distributor.sponsor_distributor.user.name rescue nil)
    }.merge({
      "name" => ("#{dha.firstname} #{dha.lastname}" rescue ' '),
      "country" => (dha.country.name rescue nil),
      "phone" => (dha.phone rescue nil),
      "co-name" => (dha.joint_lastname + ', ' + dha.joint_firstname rescue nil),
      'currency-symbol' => (self.country.currency.symbol rescue nil)
    })
  end

  def distributor_customer_id
    {"customer-id" => distributor.customer_id}
  end

  def self.usersql(params)
    sql = "SELECT   d.id distributor_id,
                    d.next_renewal_date,
                    d_sponsor.id as sponsor_id,
                    d.customer_id,
                    d.taxnumber,
                    d.date_of_birth,
                    u.id,
                    u.email,
                    u.login,
                    u.status_id,
                    u.entry_date,
                    s.name status_name,
                    string_agg(r.name, ', ') as role,
                    string_agg(r.role_code, ', ') as role_code,
                    c.iso_name country,
                    ss.name state,
                    add.lastname || ', ' || add.firstname as user_name,
                    add.joint_lastname || ', ' || add.joint_firstname as co_app_name,
                    add_entry.lastname || ', ' || add_entry.firstname as entry_by,
                    add_sponsor.lastname || ', ' || add_sponsor.firstname as sponsor_name,
                    add.phone
           FROM     users u
      LEFT JOIN     distributors d                      ON    d.user_id = u.id
      LEFT JOIN     distributors d_sponsor              ON    d.personal_sponsor_distributor_id = d_sponsor.id
      LEFT JOIN     users u_sponsor                     ON    d_sponsor.user_id = u_sponsor.id
      LEFT JOIN     users u_entry                       ON    u_entry.id = u.entry_operator
      LEFT JOIN     users_home_addresses u_home_add     ON  ( u_home_add.user_id = u.id and u_home_add.active = true and u_home_add.is_default = true )
      LEFT JOIN     users_home_addresses sponsor_add    ON  ( sponsor_add.user_id = u_sponsor.id and sponsor_add.active = true and sponsor_add.is_default = true )
      LEFT JOIN     users_home_addresses u_entry_add    ON  ( u_entry_add.user_id = u_sponsor.id and u_entry_add.active = true and u_entry_add.is_default = true )
      LEFT JOIN     roles_users ru                      ON  ( ru.user_id = u.id and ru.role_id != 10 )
      LEFT JOIN     roles r                             ON    ru.role_id = r.id
      LEFT JOIN     statuses s                          ON    s.id = u.status_id
      LEFT JOIN     addresses add                       ON    u_home_add.address_id = add.id
      LEFT JOIN     addresses add_sponsor               ON    sponsor_add.address_id = add_sponsor.id
      LEFT JOIN     addresses add_entry                 ON    u_entry_add.address_id = add_entry.id
      LEFT JOIN     countries c                         ON    c.id = add.country_id
      LEFT JOIN     states ss                           ON    add.state_id = ss.id
                    #{params[:where]}
       GROUP BY     distributor_id, d.next_renewal_date, sponsor_id, sponsor_name, d.customer_id, d.taxnumber, user_name,
                    u.id, u.email, u.login, u.status_id, u.entry_date, entry_by, status_name, country, state, add.phone, co_app_name,
                    d.date_of_birth
       ORDER BY     #{params[:column]} #{params[:order]} "
    ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
  end

  def self.total_active_distributors(month_date, country)
    sql = "SELECT COUNT(*)
           FROM     users u
      LEFT JOIN     distributors d                      ON    d.user_id = u.id
      LEFT JOIN     users_home_addresses u_home_add     ON  ( u_home_add.user_id = u.id and u_home_add.active = true and u_home_add.is_default = true )
      LEFT JOIN     addresses add                       ON    u_home_add.address_id = add.id
      LEFT JOIN     roles_users ru                      ON  ( ru.user_id = u.id and ru.role_id != 10 )
      LEFT JOIN     roles r                             ON    ru.role_id = r.id
      LEFT JOIN     countries c                         ON    c.id = add.country_id
          WHERE     u.created_at   <    '#{month_date}'
            AND     u.status_id    =    1
            AND     r.role_code    =   'D'
            AND     d.id is not null
    "
    sql += " AND c.iso_name = \'#{country}\'" if country.present?
    count = ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
    count[0]['count'].to_i
  end

  def self.total_current_month_change_active_distributors(country)
    sql = "SELECT COUNT(*)
           FROM     user_status_changes usc
      LEFT JOIN     users u                             ON  u.id = usc.user_id
      LEFT JOIN     distributors d                      ON  d.user_id = u.id
      LEFT JOIN     users_home_addresses u_home_add     ON  ( u_home_add.user_id = u.id and u_home_add.active = true and u_home_add.is_default = true )
      LEFT JOIN     addresses add                       ON  u_home_add.address_id = add.id
      LEFT JOIN     countries c                         ON  c.id = add.country_id
           WHERE    usc.created_at      >=   '#{Date.today.beginning_of_month}'
             AND    usc.created_at      <=   '#{Date.today.end_of_month}'
             AND    u.created_at        <    '#{Date.today.beginning_of_month}'
             AND    usc.old_status_id   =   1
    "
    sql += " AND c.iso_name = \'#{country}\'" if country.present?
    sql_where = " AND c.iso_name = \'#{country}\' " if country.present?
    sql1 = "SELECT COUNT(*) FROM (
      SELECT DISTINCT ON (urc.user_id) urc.user_id, urc.old_role_id, urc.new_role_id, urc.created_at
                 FROM     user_role_changes urc
            LEFT JOIN     users u                             ON  u.id = urc.user_id
            LEFT JOIN     distributors d                      ON  d.user_id = u.id
            LEFT JOIN     users_home_addresses u_home_add     ON  ( u_home_add.user_id = u.id and u_home_add.active = true and u_home_add.is_default = true )
            LEFT JOIN     addresses add                       ON  u_home_add.address_id = add.id
            LEFT JOIN     countries c                         ON  c.id = add.country_id
                 WHERE    urc.created_at      >=   '#{Date.today.beginning_of_month}'
                   AND    urc.created_at      <=   '#{Date.today.end_of_month}'
                   AND    u.created_at        <    '#{Date.today.beginning_of_month}'
                   #{sql_where}
              ORDER BY    urc.user_id, urc.old_role_id, urc.new_role_id, urc.created_at desc
      ) AS u     WHERE    u.old_role_id     =   2
                   AND    u.new_role_id     =   6
    "

    sql2 = "SELECT COUNT(*) FROM (
      SELECT DISTINCT ON (urc.user_id) urc.user_id, urc.old_role_id, urc.new_role_id, urc.created_at
                 FROM     user_role_changes urc
            LEFT JOIN     users u                             ON  u.id = urc.user_id
            LEFT JOIN     distributors d                      ON  d.user_id = u.id
            LEFT JOIN     users_home_addresses u_home_add     ON  ( u_home_add.user_id = u.id and u_home_add.active = true and u_home_add.is_default = true )
            LEFT JOIN     addresses add                       ON  u_home_add.address_id = add.id
            LEFT JOIN     countries c                         ON  c.id = add.country_id
                 WHERE    urc.created_at      >=   '#{Date.today.beginning_of_month}'
                   AND    urc.created_at      <=   '#{Date.today.end_of_month}'
                   AND    u.created_at        <    '#{Date.today.beginning_of_month}'
                   #{sql_where}
              ORDER BY    urc.user_id, urc.old_role_id, urc.new_role_id, urc.created_at desc
      ) AS u     WHERE    u.old_role_id     =   6
                   AND    u.new_role_id     =   2
    "
    total_user_status_change = ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
    total_user_role_change   = ActiveRecord::Base.connection.select_all(sanitize_sql(sql1))
    total_user_role_change_downgrade   = ActiveRecord::Base.connection.select_all(sanitize_sql(sql2))
    total_user_role_change[0]['count'].to_i + total_user_status_change[0]['count'].to_i - total_user_role_change_downgrade[0]['count'].to_i
  end

  def self.count
    sql = "select count(*) from users"
    ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
  end

  def default_home_address
    self.users_home_addresses.where(:is_default => true).first.address rescue nil
  end

  def entry_by
    self.entry_user.nil? ? nil : self.entry_user.name
  end

  def name
    default_home_address.attributes.values_at("lastname", "firstname").join(", ") rescue ' '
  end

  def country
    default_home_address.country rescue nil
  end

  def update_user_role_change
    if self.status_id_changed?
      UserStatusChange.create(user_id: self.id, old_status_id: self.status_id_was, new_status_id: self.status_id, notes: "change status_id from #{self.status_id_was} to #{self.status_id}" )
    end
  end

end

