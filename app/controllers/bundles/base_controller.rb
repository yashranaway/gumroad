# frozen_string_literal: true

class Bundles::BaseController < Sellers::BaseController
  before_action :set_bundle
  before_action :set_title

  layout "inertia"

  private
    def set_bundle
      @bundle = Link.can_be_bundle.find_by_external_id!(params[:bundle_id])
      authorize @bundle unless skip_bundle_authorization?
    end

    def skip_bundle_authorization?
      false
    end

    def set_title
      @title = @bundle.name
    end

    def presenter
      @presenter ||= BundlePresenter.new(bundle: @bundle)
    end

    def bundle_permitted_params
      params.permit(policy(@bundle).bundle_permitted_attributes)
    end

    def inertia_errors_props
      {
        errors: @bundle.errors.to_hash,
        alert: @bundle.errors.full_messages.to_sentence
      }
    end
end
