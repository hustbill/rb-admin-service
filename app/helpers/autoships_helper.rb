module AutoshipsHelper

  def get_autoship_process_dates(start_date, active_date)
    months = []
    begin_date = start_date.instance_of?(Date) ? start_date : Date.parse(start_date)
    begin_date = Date.parse("#{begin_date.strftime('%Y-%m')}-#{active_date}")
    while begin_date <= Time.now.to_date
      months << begin_date.strftime('%Y-%-m-%-d')
      begin_date = begin_date.next_month
    end
    months
  end

end