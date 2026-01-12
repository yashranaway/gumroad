# frozen_string_literal: true

class Bundles::ContentsController < Bundles::BaseController
  def edit
    props = presenter.content_edit_props
    props[:search_data] = InertiaRails.defer(merge: true) do
      {
        products: search_results[:products],
        has_more: search_results[:has_more],
        query: params[:query] || "",
        page: (params[:page] || 1).to_i,
      }
    end

    render inertia: "Bundles/Content/Edit", props: props
  end

  def update
    begin
      @bundle.is_bundle = true
      @bundle.native_type = Link::NATIVE_TYPE_BUNDLE
      update_bundle_products(bundle_permitted_params[:products]) unless bundle_permitted_params[:products].nil?
      @bundle.save!
    rescue ActiveRecord::RecordNotSaved, ActiveRecord::RecordInvalid, Link::LinkInvalid => e
      Rails.logger.error("Bundle content update failed: #{e.message}")
      redirect_to edit_bundle_content_path(@bundle.external_id),
                  inertia: inertia_errors_props,
                  alert: @bundle.errors.full_messages.first || e.message
      return
    end

    redirect_to edit_bundle_content_path(@bundle.external_id), notice: "Changes saved!", status: :see_other
  end

  def update_purchases_content
    unless @bundle.has_outdated_purchases?
      redirect_to edit_bundle_content_path(@bundle.external_id),
                  alert: "This bundle has no purchases with outdated content."
      return
    end

    UpdateBundlePurchasesContentJob.perform_async(@bundle.id)
    redirect_to edit_bundle_content_path(@bundle.external_id),
                notice: "Content update job has been queued.",
                status: :see_other
  end

  private
    def search_results
      @search_results ||= BundleSearchProductsService.new(
        bundle: @bundle,
        seller: current_seller,
        query: params[:query],
        page: params[:page] || 1,
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
