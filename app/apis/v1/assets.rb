module V1
  class Assets < ::BaseAPI
    version 'v1', using: :path
    namespace 'admin' do

      desc 'images sortable'
      post 'assets/sortable' do
        params[:assets_ids].each_with_index do |asset_id, index|
          Asset.where(id: asset_id.to_i).update_all(position: index + 1)
        end
        generate_success_response('ok')
      end

    end #namespace admin
  end
end