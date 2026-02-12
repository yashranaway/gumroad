# frozen_string_literal: true

class Communities::LastReadChatMessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_community
  after_action :verify_authorized

  layout "inertia"

  def create
    message = @community.community_chat_messages.find_by_external_id(params[:message_id])
    return e404 unless message

    LastReadCommunityChatMessage.set!(
      user_id: current_seller.id,
      community_id: @community.id,
      community_chat_message_id: message.id,
    )

    redirect_to community_path(seller_id: @community.seller.external_id, community_id: @community.external_id), status: :see_other
  end

  private
    def set_community
      @community = Community.find_by_external_id(params[:community_id])
      return e404 unless @community

      authorize @community, :show?
    end
end
