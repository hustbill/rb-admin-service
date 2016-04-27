module V1
  class InterestedCustomers < ::BaseAPI
    version 'v1', using: :path
    namespace "admin" do

      desc "register"
      params do
        optional :first_name, :type => String
        optional :last_name, :type => String
        optional :city, :type => String
        optional :country, :type => String
        optional :state, :type => String
        optional :zip_code, :type => String
        optional :email, :type => String
        optional :phone, :type => String
        optional :intro, :type => String
      end
      post 'interested_customers/register' do
        customer = InterestedCustomer.new(
          first_name: params['first_name'],
          last_name: params['last_name'],
          city: params['city'],
          country: params['country'],
          state: params['state'],
          zip_code: params['zip_code'],
          email: params['email'],
          phone: params['phone'],
          intro: params['intro'])
        if customer.save
          generate_success_response("ok")
        else
          generate_error_response("error")
        end
      end

      desc "list"
      params do
        optional :limit, :type => Integer, :default => 25
        optional :offset, :type => Integer, :default => 0
      end
      get 'interested_customers' do
        records = InterestedCustomer.limit(params[:limit]).offset(params[:offset]).order("id desc")
        r = {
          "meta" => {
            :limit => params[:limit],
            :offset => params[:offset],
            :count => InterestedCustomer.count
          },
          "records" => records
        }
        generate_success_response(r)
      end

      desc "delete"
      params do
        optional :id, :type => Integer
      end
      post 'interested_customers/:id/delete' do
        InterestedCustomer.delete(params[:id])
        generate_success_response("ok")
      end
    end
  end
end