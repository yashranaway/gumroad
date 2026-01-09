# frozen_string_literal: true

class Bundles::ContentController < Bundles::BaseController
  def edit
    props = bundle_props
    props[:tab] = "content"

    props[:search_products] = InertiaRails.defer(merge: true) do
      search_results[:products]
    end

    props[:search_has_more] = InertiaRails.defer do
      search_results[:has_more]
    end

    props[:search_page] = InertiaRails.defer do
      search_results[:page]
    end

    render inertia: "Bundles/ContentTab", props:
  end

  def update
    authorize @bundle

    if params[:products].present?
      begin
        @bundle.is_bundle = true
        @bundle.native_type = Link::NATIVE_TYPE_BUNDLE
        update_bundle_products(content_permitted_params[:products])
        @bundle.save!
      rescue ActiveRecord::RecordNotSaved, ActiveRecord::RecordInvalid, Link::LinkInvalid => e
        error_message = @bundle.errors.full_messages.first || e.message
        return redirect_to bundles_edit_content_path(@bundle.external_id), alert: error_message
      end
    end

    redirect_to bundles_edit_content_path(@bundle.external_id), notice: "Changes saved!", status: :see_other
  end

  def update_purchases_content
    authorize @bundle, :update?

    return render json: { error: "This bundle has no purchases with outdated content." }, status: :forbidden unless @bundle.has_outdated_purchases?

    UpdateBundlePurchasesContentJob.perform_async(@bundle.id)

    head :no_content
  end

  private
    def content_permitted_params
      params.permit(products: [:product_id, :variant_id, :quantity, :position])
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

    def update_bundle_products(new_bundle_products)
      bundle_products = @bundle.bundle_products.includes(:product)

      bundle_products.each do |bundle_product|
        new_bundle_product = new_bundle_products.find { _1[:product_id] == bundle_product.product.external_id }
        if new_bundle_product.present?
          bundle_product.update(variant: BaseVariant.find_by_external_id(new_bundle_product[:variant_id]), quantity: new_bundle_product[:quantity], deleted_at: nil, position: new_bundle_product[:position])
          new_bundle_products.delete(new_bundle_product)
          update_has_outdated_purchases
        else
          bundle_product.mark_deleted!
        end
      end

      update_has_outdated_purchases if new_bundle_products.present?

      new_bundle_products.each do |new_bundle_product|
        product = Link.find_by_external_id!(new_bundle_product[:product_id])
        variant = BaseVariant.find_by_external_id(new_bundle_product[:variant_id])

        @bundle.bundle_products.create!(product:, variant:, quantity: new_bundle_product[:quantity], position: new_bundle_product[:position])
      end
    end

    def update_has_outdated_purchases
      return if @bundle.has_outdated_purchases?

      @bundle.has_outdated_purchases = true if @bundle.successful_sales_count > 0
    end
end
