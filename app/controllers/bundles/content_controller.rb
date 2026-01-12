# frozen_string_literal: true

class Bundles::ContentController < Bundles::BaseController
  def edit
    props = BundlePresenter.new(bundle: @bundle).edit_content_props
    props[:tab] = "content"

    props[:search_data] = InertiaRails.defer(merge: true) do
      results = search_results
      {
        products: results[:products],
        has_more: results[:has_more],
        page: results[:page],
      }
    end

    render inertia: "Bundles/Content/Edit", props:
  end

  def update
    authorize @bundle

    begin
      Bundle::UpdateProductsService.new(bundle: @bundle, products: content_permitted_params[:products]).perform
      @bundle.save!
    rescue ActiveRecord::RecordNotSaved, ActiveRecord::RecordInvalid, Link::LinkInvalid => e
      error_message = @bundle.errors.full_messages.first || e.message
      return redirect_to edit_bundle_content_path(@bundle.external_id), alert: error_message
    end

    redirect_to edit_bundle_content_path(@bundle.external_id), notice: "Changes saved!", status: :see_other
  end

  def update_purchases_content
    unless @bundle.has_outdated_purchases?
      redirect_to edit_bundle_content_path(@bundle.external_id), alert: "This bundle has no purchases with outdated content.", status: :see_other
      return
    end

    UpdateBundlePurchasesContentJob.perform_async(@bundle.id)

    redirect_to edit_bundle_content_path(@bundle.external_id), notice: "Queued an update to the content of all outdated purchases.", status: :see_other
  end

  private
    def content_permitted_params
      products_param = params.fetch(:products, [])
      { products: Array(products_param).map { |p| p.permit(:product_id, :variant_id, :quantity, :position) } }
    end

    def search_results
      @search_results ||= BundleSearchProductsService.new(
        bundle: @bundle,
        seller: current_seller,
        query: params[:query].presence,
        page: params[:page].presence || 1,
        all: params[:all] == "true"
      ).call
    end
end
