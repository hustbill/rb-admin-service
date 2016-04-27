module V1
  class Preferences < ::BaseAPI
    version 'v1', using: :path
    namespace 'admin' do

      resource :preferences do

        desc 'get order adjustments'
        get 'order_adjustment_labels' do
          generate_success_response(Preference.order_adjustment_labels.map(&:decorated_attributes))
        end

        desc 'add order adjustment'
        post 'add_order_adjustment_label' do
          order_adjustment = Preference.find_by owner_type: 'ManualOrderAdjustment',
                                                owner_id: 1,
                                                name: 'label',
                                                value: params[:label]

          if order_adjustment.nil? && params[:label].present?
            preserence = Preference.new owner_type: 'ManualOrderAdjustment',
                                        owner_id: 1,
                                        name: 'label',
                                        value: params[:label]
            if preserence.save
              generate_success_response('ok')
            else
              return_error_response('error')
            end
          else
            generate_success_response('the order adjustment exists.')
          end
        end

      end

    end #namespace admin
  end
end