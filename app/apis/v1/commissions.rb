module V1
  class Commissions < ::BaseAPI
    version 'v1', using: :path
    namespace 'admin' do

      desc 'commissions weekly'
      get 'commissions/weekly' do
        weekly_dates = Commission.get_weekly_select_option_dates
        start_date   = params[:commission_date].present? ? params[:commission_date] : weekly_dates[weekly_dates.first[0]][0][1]
        generate_success_response({
          weekly_select_option_dates: weekly_dates,
          start_date:     start_date,
          summary:        Commission.get_commissions_weekly_summary(start_date: start_date),
          team_profits:   Commission.get_commissions_weekly_bonus_detail(start_date: start_date),
          match_profits:  Commission.get_commissions_weekly_match_profits(start_date: start_date),
          fob_earnings:   Commission.get_commissions_fasttrack( params.merge(start_date: start_date) ),
          retail_earning: Commission.get_commissions_retail( params.merge(start_date: start_date) )
        })
      end


      desc 'commissions monthly'
      get 'commissions/monthly' do
        start_date = params[:start_date].present? ? params[:start_date] : Commission.get_all_monthly_data_table_names.first.values[0][-8..-1]
        generate_success_response({
          summary:           Commission.get_commissions_monthly_summary(start_date: start_date),
          unilevel:          Commission.get_commissions_month_bonus_info(start_date: start_date, table_tail: 'unilevel'),
          generationalmatch: Commission.get_commissions_month_bonus_info(start_date: start_date, table_tail: 'generationalmatch'),
          lifestyle:         Commission.get_commissions_month_bonus_info(start_date: start_date, table_tail: 'lifestyle'),
          leadershippool:    Commission.get_commissions_month_bonus_info(start_date: start_date, table_tail: 'leadershippool'),
          monthly_select_option_dates: Commission.get_monthly_select_option_dates,
          start_date:                  start_date
        })
      end


      desc 'commissions detail info'
      get 'commissions/detail_info' do
        start_date = params[:start_date].present? ? params[:start_date] : Commission.get_all_monthly_data_table_names.first.values[0][-8..-1]

        generate_success_response(Commission.get_commissions_month_detail_info(type: params[:type],
                                                                               start_date: start_date,
                                                                               distributor_id: params[:distributor_id]))
      end

    end


  end
end
