# frozen_string_literal: true

class Communities::NotificationSettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_community
  after_action :verify_authorized

  layout "inertia"

  def update
    settings = current_seller.community_notification_settings.find_or_initialize_by(seller: @community.seller)
    settings.update!(permitted_params)

    redirect_to community_path(seller_id: @community.seller.external_id, community_id: @community.external_id), status: :see_other
  end

  private
    def set_community
      @community = Community.find_by_external_id(params[:community_id])
      return e404 unless @community

      authorize @community, :show?
    end

    def permitted_params
      params.require(:settings).permit(:recap_frequency)
    end
end
