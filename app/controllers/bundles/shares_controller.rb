# frozen_string_literal: true

class Bundles::SharesController < Bundles::BaseController
  before_action :ensure_published

  def edit
    render inertia: "Bundles/Share/Edit", props: presenter.share_edit_props
  end

  def update
    begin
      @bundle.assign_attributes(bundle_permitted_params.except(:tags, :section_ids))
      @bundle.save_tags!(bundle_permitted_params[:tags]) unless bundle_permitted_params[:tags].nil?
      @bundle.show_in_sections!(bundle_permitted_params[:section_ids]) if bundle_permitted_params[:section_ids]
      @bundle.save!
    rescue ActiveRecord::RecordNotSaved, ActiveRecord::RecordInvalid, Link::LinkInvalid => e
      Rails.logger.error("Bundle share update failed: #{e.message}")
      redirect_to edit_bundle_share_path(@bundle.external_id),
                  inertia: inertia_errors_props,
                  alert: @bundle.errors.full_messages.first || e.message
      return
    end

    redirect_to edit_bundle_share_path(@bundle.external_id), notice: "Changes saved!", status: :see_other
  end

  private
    def ensure_published
      return if @bundle.published?

      redirect_to edit_bundle_content_path(@bundle.external_id),
                  alert: "Not yet! You've got to publish your awesome product before you can share it with your audience and the world."
    end
end
