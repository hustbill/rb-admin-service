module V1
  class Users < ::BaseAPI
    version 'v1', using: :path
    namespace "admin" do

      desc 'terminate list all users.'
      params do
        optional :limit,  :type => Integer, :default => 25
        optional :offset, :type => Integer, :default => 0
        optional :all,    :type => Boolean, :default => false
      end
      get 'users/terminate' do
        params[:column] = sort_column
        params[:order]  = sort_direction_fix
        params[:where]  = terminate_search_fix
        result = User.usersql(params)
        count = result.count
        if params[:all]
          users = result
        else
          users = result[params[:offset]..params[:offset]+params[:limit]-1]
        end
        r = {
            "meta" => {
                :limit => params[:limit],
                :offset => params[:offset],
                :count => count
            },
            "users" => users
        }
        generate_success_response(r)
      end

      desc 'list all inactive users'
      params do
        optional :limit,  :type => Integer, :default => 25
        optional :offset, :type => Integer, :default => 0
        optional :all,    :type => Boolean, :default => false
      end
      get 'users/inactived' do
        params[:column] = sort_column
        params[:order]  = sort_direction_fix
        params[:where]  = inactive_search_fix
        result = User.usersql(params)
        count = result.count
        if params[:all]
          users = result
        else
          users = result[params[:offset]..params[:offset]+params[:limit]-1]
        end
        r = {
            "meta" => {
                :limit => params[:limit],
                :offset => params[:offset],
                :count => count
            },
            "users" => users
        }
        generate_success_response(r)
      end

      desc 'list all expired users by expired day'
      params do
        optional :limit,  :type => Integer, :default => 25
        optional :offset, :type => Integer, :default => 0
        optional :all,    :type => Boolean, :default => false
      end
      get 'users/expired' do
        params[:column] = sort_column
        params[:order]  = sort_direction_fix
        params[:where]  = expired_search_fix
        result = User.usersql(params)
        count  = result.count
        if params[:all]
          users = result
        else
          users = result[params[:offset]..params[:offset]+params[:limit]-1]
        end
        r = {
            "meta" => {
                :limit  => params[:limit],
                :offset => params[:offset],
                :count  => count
            },
            "users" => users
        }
        generate_success_response(r)
      end

      desc "contact"
      params do
        requires :login, type: String, desc: 'login'
      end
      get 'users/contact' do
        @user = User.find_by_login params[:login]
        if @user.nil?
          return_error_response("the user is not found", 404)
        else
          generate_success_response(@user.decorated_attributes)
        end
      end

      desc 'user tracks'
      params do
        optional :limit,  :type => Integer, :default => 25
        optional :offset, :type => Integer, :default => 0
      end
      get 'users/tracks' do
        search       = UserTrack.joins(:user).search(params[:q])
        user_tracks  = search.result.limit(params[:limit]).offset(params[:offset]).order('user_tracks.sign_in_at desc')
        generate_success_response({
          'meta' => {
            :count =>  search.result.count,
            :limit =>  params[:limit],
            :offset => params[:offset]
          },
          'user_tracks' => user_tracks.map(&:decorated_attributes)
        })
      end

      desc "list all active countries"
      get 'users/countries' do
        r = Country.all_clientactive
        generate_success_response(r)
      end

      desc "update user status"
      params do
        requires :distributor_id, type: Integer
        requires :status_id, type: Integer
      end
      post 'users/update_status' do
        @user = Distributor.find(params[:distributor_id]).user
        if @user.update_attribute(:status_id, params[:status_id])
          generate_success_response("success")
        else
          generate_error_response("the user is not found", 404)
        end
      end

      desc "Terminate an user"
      params do
        requires :id, type: Integer, desc: "User id."
      end
      post 'users/:id/terminate' do
        @user = User.find(params[:id])
        if  @user.update_attribute(:status_id, 6)
          if @user.distributor
            @user.distributor.update_attributes(taxnumber: nil, taxnumber_exemption: nil, social_security_number: nil)
            OauthToken.where(distributor_id: @user.distributor.id).update_all(active: false)
          end
          generate_success_response("success")
        else
          generate_error_response("the user is not found", 404)
        end
      end

      desc "Return an user"
      params do
        requires :id, type: Integer, desc: "User id."
      end
      get 'users/:id' do
        @user = User.find(params[:id])
        if @user
          generate_success_response(@user.decorated_attributes)
        else
          generate_error_response("the user is not found", 404)
        end
      end

      desc 'list all users.'
      params do
        optional :limit, :type => Integer, :default => 25
        optional :offset, :type => Integer, :default => 0
        optional :all, :type => Boolean, :default => false
      end
      get 'users' do
        params[:column] = sort_column
        params[:order]  = sort_direction_fix
        params[:where]  = search_fix
        result = User.usersql(params)
        count = result.count
        previous_total_active_distributors  = User.total_active_distributors(Date.today.beginning_of_month, params['country']) + User.total_current_month_change_active_distributors(params['country'])
        current_total_active_distributors   = User.total_active_distributors(Date.today.beginning_of_month.next_month.next_month, params['country'])
        if params[:all]
          users = result
        else
          users = result[params[:offset]..params[:offset]+params[:limit]-1]
        end
        r = {
          "meta" => {
            :limit => params[:limit],
            :offset => params[:offset],
            :count => count,
            :current_total_active_distributors  => current_total_active_distributors,
            :previous_total_active_distributors => previous_total_active_distributors
          },
          "users" => users
        }
        generate_success_response(r)
      end

      desc "list all user_notes."
      get 'users/:id/notes' do
        @user = User.find params[:id]
        if @user
          generate_success_response({ notes: @user.admin_notes.map(&:decorated_attributes), username: @user.name})
        else
          generate_error_response('error')
        end
      end

      desc "create a note by user id."
      post "users/:id/add_note" do
        @user = User.find params[:id]
        note = @user.admin_notes.build note: params[:note], user_id: headers["X-User-Id"]
        if note.save
          generate_success_response({ notes: @user.admin_notes.map(&:decorated_attributes), username: @user.name})
        else
          generate_error_response('error')
        end
      end
    end
  end


end
