# frozen_string_literal: true

class Bundles::ProductController < Bundles::BaseController
  def edit
    props = bundle_props
    props[:tab] = "product"

    render inertia: "Bundles/ProductTab", props:
  end

  def update
    authorize @bundle

    begin
      @bundle.is_bundle = true
      @bundle.native_type = Link::NATIVE_TYPE_BUNDLE
      @bundle.assign_attributes(product_permitted_params.except(
        :products, :custom_button_text_option, :custom_summary, :custom_attributes, :tags, :covers, :refund_policy, :product_refund_policy_enabled,
        :seller_refund_policy_enabled, :section_ids, :installment_plan)
      )
      @bundle.save_custom_button_text_option(product_permitted_params[:custom_button_text_option]) unless product_permitted_params[:custom_button_text_option].nil?
      @bundle.save_custom_summary(product_permitted_params[:custom_summary]) unless product_permitted_params[:custom_summary].nil?
      @bundle.save_custom_attributes(product_permitted_params[:custom_attributes]) unless product_permitted_params[:custom_attributes].nil?
      @bundle.save_tags!(product_permitted_params[:tags]) unless product_permitted_params[:tags].nil?
      @bundle.reorder_previews(product_permitted_params[:covers].map.with_index.to_h) if product_permitted_params[:covers].present?
      if !current_seller.account_level_refund_policy_enabled?
        @bundle.product_refund_policy_enabled = product_permitted_params[:product_refund_policy_enabled]
        if product_permitted_params[:refund_policy].present? && @bundle.product_refund_policy_enabled
          @bundle.find_or_initialize_product_refund_policy.update!(product_permitted_params[:refund_policy])
        elsif @bundle.product_refund_policy_enabled == false && @bundle.product_refund_policy.present?
          @bundle.product_refund_policy.destroy
        end
      end
      @bundle.show_in_sections!(product_permitted_params[:section_ids]) if product_permitted_params[:section_ids]

      update_installment_plan
      update_bundle_products(product_permitted_params[:products]) unless product_permitted_params[:products].nil?
      @bundle.save!
    rescue ActiveRecord::RecordNotSaved, ActiveRecord::RecordInvalid, Link::LinkInvalid => e
      error_message = @bundle.errors.full_messages.first || e.message
      return redirect_to bundles_edit_product_path(@bundle.external_id), alert: error_message
    end

    redirect_to bundles_edit_product_path(@bundle.external_id), notice: "Changes saved!", status: :see_other
  end

  private
    def product_permitted_params
      params.permit(policy(@bundle).bundle_permitted_attributes)
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

    def update_installment_plan
      return unless @bundle.eligible_for_installment_plans?

      if @bundle.installment_plan && product_permitted_params[:installment_plan].present?
        @bundle.installment_plan.assign_attributes(product_permitted_params[:installment_plan])
        return unless @bundle.installment_plan.changed?
      end

      @bundle.installment_plan&.destroy_if_no_payment_options!
      @bundle.reset_installment_plan

      if product_permitted_params[:installment_plan].present?
        @bundle.create_installment_plan!(product_permitted_params[:installment_plan])
      end
    end
end
