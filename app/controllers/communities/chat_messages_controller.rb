# frozen_string_literal: true

class Communities::ChatMessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_community
  before_action :set_message, only: [:update, :destroy]
  after_action :verify_authorized

  layout "inertia"

  def create
    message = @community.community_chat_messages.build(permitted_params)
    message.user = current_seller

    if message.save
      message_props = CommunityChatMessagePresenter.new(message:).props
      broadcast_message(message_props, CommunityChannel::CREATE_CHAT_MESSAGE_TYPE)
      redirect_to community_path(seller_id: @community.seller.external_id, community_id: @community.external_id)
    else
      redirect_to community_path(seller_id: @community.seller.external_id, community_id: @community.external_id),
                  inertia: { errors: { content: message.errors.full_messages.first } }
    end
  end

  def update
    if @message.update(permitted_params)
      message_props = CommunityChatMessagePresenter.new(message: @message).props
      broadcast_message(message_props, CommunityChannel::UPDATE_CHAT_MESSAGE_TYPE)
      redirect_to community_path(seller_id: @community.seller.external_id, community_id: @community.external_id)
    else
      redirect_to community_path(seller_id: @community.seller.external_id, community_id: @community.external_id),
                  inertia: { errors: { content: @message.errors.full_messages.first } }
    end
  end

  def destroy
    @message.mark_deleted!
    message_props = CommunityChatMessagePresenter.new(message: @message).props
    broadcast_message(message_props, CommunityChannel::DELETE_CHAT_MESSAGE_TYPE)
    redirect_to community_path(seller_id: @community.seller.external_id, community_id: @community.external_id)
  end

  private
    def set_community
      @community = Community.find_by_external_id(params[:community_id])
      return e404 unless @community

      authorize @community, :show?
    end

    def set_message
      @message = @community.community_chat_messages.find_by_external_id(params[:id])
      return e404 unless @message

      authorize @message
    end

    def permitted_params
      params.require(:community_chat_message).permit(:content)
    end

    def broadcast_message(message_props, type)
      CommunityChannel.broadcast_to(
        "community_#{@community.external_id}",
        { type:, message: message_props },
      )
    rescue => e
      Rails.logger.error("Error broadcasting message to community channel: #{e.message}")
      Bugsnag.notify(e)
    end
end
