# frozen_string_literal: true

class Bundles::BaseController < Sellers::BaseController
  include Product::BundlesMarketing

  layout "inertia"

  before_action :set_bundle
  before_action :authorize_bundle
  before_action :set_title

  protected
    def set_bundle
      @bundle = Link.can_be_bundle.find_by_external_id!(params[:bundle_id] || params[:id])
    end

    def authorize_bundle
      authorize @bundle
    end

    def set_title
      @title = @bundle.name
    end
end
