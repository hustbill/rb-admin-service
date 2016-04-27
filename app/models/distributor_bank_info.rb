class DistributorBankInfo < ActiveRecord::Base

  belongs_to :distributor

  def self.by_country(query_params)
      if query_params[:start_date].blank?
        query_params[:start_date] = Time.now.strftime("%Y-%m-%d")
      else
        query_params[:start_date] = "#{query_params[:start_date]}".to_date.strftime("%Y-%m-%d")
      end
      if query_params[:end_date].blank?
        query_params[:end_date] = Time.now.strftime("%Y-%m-%d")
      else
        query_params[:end_date] = "#{query_params[:end_date]}".to_date.strftime("%Y-%m-%d")
      end
      query_params[:end_date] = (query_params[:end_date].to_date + 1).strftime("%Y-%m-%d")
      country_id = query_params[:country_id].to_i

      sql = "
                SELECT add.lastname || ', ' || add.firstname as name,
                       dbi.*,
                       c.iso_name
                  FROM distributor_bank_infos dbi
             LEFT JOIN distributors d ON dbi.distributor_id = d.id
             LEFT JOIN users_home_addresses uha ON d.user_id = uha.user_id AND uha.is_default = true AND uha.active = true
             LEFT JOIN addresses add ON uha.address_id = add.id
             LEFT JOIN countries c ON c.id = add.country_id
                 WHERE dbi.updated_at >= '#{query_params[:start_date]}'
                   AND dbi.updated_at < '#{query_params[:end_date]}'
                   AND c.id = #{country_id}
              ORDER BY dbi.updated_at, dbi.distributor_id
            "
      ActiveRecord::Base.connection.select_all(sanitize_sql(sql))
  end

end
