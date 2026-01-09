# frozen_string_literal: true

class Bundles::BaseController < Sellers::BaseController
  include Product::BundlesMarketing

  layout "inertia"

  before_action :set_bundle
  before_action :authorize_bundle

  private
    def set_bundle
      @bundle = Link.can_be_bundle.find_by_external_id!(params[:id])
    end

    def authorize_bundle
      authorize @bundle
      @title = @bundle.name
    end

    def bundle_props
      BundlePresenter.new(bundle: @bundle).bundle_props
    end
end
