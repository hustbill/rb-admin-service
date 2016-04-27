module V1
  class Autoships < ::BaseAPI
    version 'v1', using: :path
    namespace "admin" do
      helpers AutoshipsHelper
      
      desc 'list all autoships.'
      params do
        optional :limit, :type => Integer, :default => 25
        optional :offset, :type => Integer, :default => 0
      end
      get 'autoships' do
        @search = Autoship.search(params[:q])
        @autoships = @search.result.limit(params[:limit]).offset(params[:offset]).order("id desc")
        autoships = @autoships.map do |a|
          {
            "id" => a.id,
            "user-id" => a.user_id,
            "user-login" => a.user.login,
            "active-date" => a.active_date,
            "state" => a.state,
            "start-date" => a.start_date,
            "sent-to" => a.ship_address.try(:full_name),
            "products" => a.autoship_items.map{|item| {:variant => item.variant, :product => item.variant.product, :item => item} },
            "distributor-id" =>(a.user.distributor.id rescue nil),
            "distributor-name" =>(a.user.name rescue nil),
            'order_dates'      =>a.orders.map(&:order_date)
          }
        end
        r = {
          "meta" => {
            :count => @search.result.count,
            :limit => params[:limit],
            :offset => params[:offset]
          },
          "autoships" => autoships
        }
        generate_success_response(r)
      end

      desc 'get autoship adjustment labels'
      get 'autoships/adjustment_labels' do
        generate_success_response(Preference.autoship_adjustment_labels.map(&:decorated_attributes))
      end

      desc 'update autoship adjustment label'
      put 'autoships/update_adjustment_label' do
        preserence = Preference.find(params[:id].to_i)
        if preserence && preserence.update_attribute('value', params[:value])
          generate_success_response('ok')
        else
          return_error_response('error')
        end
      end

      desc 'delete autoship adjustment label'
      delete 'autoships/del_adjustment_label' do
        preserence = Preference.find(params[:id].to_i)
        if preserence && preserence.destroy
          generate_success_response('ok')
        else
          return_error_response('error')
        end
      end

      desc 'create autoship adjustment label'
      post 'autoships/create_adjustment_label' do
        preserence = Preference.new owner_id: 1,
                                    owner_type: 'ManualAutoshipAdjustment',
                                    name: 'label',
                                    value: params[:value]
        if preserence.save
          generate_success_response(preserence.attributes)
        else
          return_error_response('error')
        end
      end

      desc 'get autoship orders'
      get 'autoships/:id/orders' do
        orders = Order.where(autoship_id: params[:id])
        generate_success_response(orders.map(&:attributes))
      end

      desc 'get autoship process date'
      get 'autoships/:id/process_dates' do
        autoship = Autoship.find(params[:id])
        if autoship
          generate_success_response(
              get_autoship_process_dates(
                  autoship.start_date,
                  autoship.active_date
              )
          )
        else
          return_error_response('error')
        end
      end
      
    end
  end
      
      
end
