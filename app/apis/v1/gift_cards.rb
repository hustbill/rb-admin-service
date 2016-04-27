module V1
  class GiftCards < ::BaseAPI
    version 'v1', using: :path
    namespace 'admin' do
      resource 'giftcards' do

        post 'multiple/create' do
          params do
            optional :'variant-id', :type => Integer
            optional :'quantity', :type => Integer
          end

          variant = Variant.find params["variant-id"]
          if variant.nil?
            generate_error_response("The gift is not found", 500)
          else
            msg = GiftCard.multiple_create(headers["X-User-Id"], params["quantity"], variant)
            generate_success_response(msg)
          end
        end

        params do
          optional :limit, :type => Integer, :default => 25
          optional :offset, :type => Integer, :default => 0
          optional :entry_operator, :type => Integer
        end
        get do
          search = GiftCard.where.not(entry_operator: nil).order("id desc").search(params.q.try(:to_hash))
          gifts = search.result.limit(params.limit).offset(params.offset)
          results = gifts.map(&:decorated_attributes)
          r = {
            "meta" => {
              :limit => params.limit,
              :offset => params.offset,
              :count => search.result.count
            },
            "gifts" => results
          }
          generate_success_response(r)
        end

        params do
          optional :limit, :type => Integer, :default => 25
          optional :offset, :type => Integer, :default => 0
          optional :entry_operator, :type => Integer
        end
        get 'orders' do
          search = GiftCard.where.not(order_id: nil).where(active: true).order("id desc").search(params.q.try(:to_hash))
          gifts = search.result.limit(params.limit).offset(params.offset)
          results = gifts.map(&:decorated_attributes)
          r = {
            "meta" => {
              :limit => params.limit,
              :offset => params.offset,
              :count => search.result.count
            },
            "gifts" => results
          }
          generate_success_response(r)
        end

        params do
          optional :limit, :type => Integer, :default => 25
          optional :offset, :type => Integer, :default => 0
        end
        get 'rewards' do
          search = GiftCard
            .joins(:event_rewards_sources)
            .where(event_rewards_sources: {reward_source_type: "GiftCard"})
            .where(active: true)
            .order("id desc")
            .search(params.q.try(:to_hash))
          gifts = search.result.limit(params.limit).offset(params.offset)
          results = gifts.map(&:decorated_attributes)
          r = {
            "meta" => {
              :limit => params.limit,
              :offset => params.offset,
              :count => search.result.count
            },
            "gifts" => results
          }
          generate_success_response(r)
        end

        params do
          requires :id, :type => Integer
        end
        get ':id' do
          gift = GiftCard.find_by(id: params["id"])
          generate_success_response( gift: gift.decorated_attributes )
        end

        params do
          requires :id, :type => Integer
          requires :gift
        end
        put ':id' do
          gift = GiftCard.find_by(id: params["id"])
          if gift.update(params.gift)
            gift.update(active: !params.gift.active.nil?)
            generate_success_response("ok")
          else
            generate_error_response( gift.errors.full_messages.join(", ") )
          end
        end

        params do
          requires :id, :type => Integer
        end
        put ':id/update_email_count' do
          gift = GiftCard.find_by(id: params["id"])
          if gift.increment!(:send_email_count)
            generate_success_response("ok")
          else
            generate_error_response( gift.errors.full_messages.join(", ") )
          end
        end

      end
    end
  end
end
