module V1
  class BankInfos < ::BaseAPI
    version 'v1', using: :path
    namespace "admin" do

      params do
        optional :id,  :type => Integer
        optional :page, :type => Integer, :default =>1
        optional :limit, :type => Integer, :default => 25
      end
      get 'bankinfos' do
        if params[:distributor_id].present?
          res = DistributorBankInfo.where(distributor_id: params[:distributor_id])
                                   .where(params[:start_date].present? ? ['updated_at >= ?', params[:start_date].to_date.strftime('%Y-%m-%d')] : nil)
                                   .where(params[:end_date].present? ?   ['updated_at < ?',  params[:end_date].to_date.strftime('%Y-%m-%d')] : nil)
        else
          res = DistributorBankInfo.by_country(params)
        end
        r = {
            "meta" => {
                :limit => params[:limit],
                :offset => (params[:page]-1) * params[:limit],
                :count => res.count
            },
            "bankinfos" => res[(params[:page]-1)*params[:limit]..params[:page]*params[:limit]-1]
        }
        generate_success_response(r)
      end

      desc 'direct deposit'
      get 'direct_deposit' do
        r = Report.direct_deposit(params)
        generate_success_response(r)
      end

      params do
        requires :id, type: Integer
      end
      post 'bankinfos/:id' do
        bankinfo = DistributorBankInfo.find_or_create_by(distributor_id: params[:id])
        attr = {
          :distributor_id => params[:id],
          :bank_account_holder_name => params[:bank_account_holder_name],
          :bank_account_number => params[:bank_account_number],
          :bank_name => params[:bank_name],
          :bank_code => params[:bank_code],
          :branch_bank_name => params[:branch_bank_name],
          :branch_bank_code => params[:branch_bank_code],
          :account_type => params[:account_type]
        }
        bankinfo.update_attributes(attr)
        generate_success_response('ok')
      end

      desc 'get commission'
      params do
        optional :limit, :type => Integer, :default => 25
        optional :page, :type => Integer, :default => 1
      end
      get 'adjust_commission' do
        @search = CommissionAdjustment.find_all(params)
        @reports = @search[(params[:page]-1)*params[:limit]..params[:page]*params[:limit]-1]
        r = {
          "meta" => {
            :count => @search.count,
            :limit => params[:limit],
            :offset => (params[:page]-1)*params[:limit]
          },
          "reports" => @reports
        }
        generate_success_response(r)
      end

      desc 'adjust commission'
      params do
        requires :distributor_id
        requires :amount
        requires :date
      end
      post 'adjust_commission' do
        CommissionAdjustment.create_or_update(params)
        CommissionAdjustment.create_commission_or_update(params)
        generate_success_response('ok')
      end

    end #namespace admin
  end
end
