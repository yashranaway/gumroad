# frozen_string_literal: true

class CommunitiesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_default_page_title
  after_action :verify_authorized

  layout "inertia"

  def index
    authorize Community

    render inertia: "Communities/Index", props: {
      has_products: -> { current_seller.products.visible_and_not_archived.exists? },
      communities: -> { communities_presenter.community_list_props },
      notification_settings: -> { communities_presenter.notification_settings_props },
    }
  end

  def show
    seller = User.find_by_external_id!(params[:seller_id])
    community = Community.alive.find_by_external_id!(params[:community_id])
    raise ActiveRecord::RecordNotFound unless community.seller_id == seller.id

    authorize community

    messages_data = initial_messages(community)

    render inertia: "Communities/Index", props: {
      has_products: -> { current_seller.products.visible_and_not_archived.exists? },
      communities: -> { communities_presenter.community_list_props },
      notification_settings: -> { communities_presenter.notification_settings_props },
      selectedCommunityId: community.external_id,
      initial_messages: messages_data[:messages],
      next_older_timestamp: messages_data[:next_older_timestamp],
      next_newer_timestamp: messages_data[:next_newer_timestamp],
    }
  end

  private
    def set_default_page_title
      set_meta_tag(title: "Communities")
    end

    def communities_presenter
      @communities_presenter ||= CommunitiesPresenter.new(current_user: current_seller)
    end

    def initial_messages(community)
      cursor = initial_cursor(community)

      PaginatedCommunityChatMessagesPresenter.new(
        community: community,
        timestamp: cursor,
        fetch_type: "around",
      ).props
    end

    def initial_cursor(community)
      last_read = LastReadCommunityChatMessage
        .includes(:community_chat_message)
        .find_by(user_id: current_seller.id, community_id: community.id)
      last_read&.community_chat_message&.created_at&.iso8601 || Time.current.iso8601
    end
end
