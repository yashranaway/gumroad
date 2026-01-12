# frozen_string_literal: true

class Bundles::ShareController < Bundles::BaseController
  def edit
    props = BundlePresenter.new(bundle: @bundle).edit_share_props
    props[:tab] = "share"

    render inertia: "Bundles/Share/Edit", props:
  end

  def update
    authorize @bundle

    begin
      @bundle.is_bundle = true
      @bundle.native_type = Link::NATIVE_TYPE_BUNDLE
      @bundle.assign_attributes(share_permitted_params.except(:section_ids))
      @bundle.show_in_sections!(share_permitted_params[:section_ids]) if share_permitted_params[:section_ids]
      @bundle.save!
    rescue ActiveRecord::RecordNotSaved, ActiveRecord::RecordInvalid, Link::LinkInvalid => e
      error_message = @bundle.errors.full_messages.first || e.message
      return redirect_to edit_share_bundle_path(@bundle.external_id), alert: error_message
    end

    redirect_to edit_share_bundle_path(@bundle.external_id), notice: "Changes saved!", status: :see_other
  end

  private
    def share_permitted_params
      params.permit(section_ids: [])
    end
end
