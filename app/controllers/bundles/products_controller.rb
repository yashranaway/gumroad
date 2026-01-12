# frozen_string_literal: true

class Bundles::ProductsController < Bundles::BaseController
  def edit
    render inertia: "Bundles/Product/Edit", props: presenter.product_edit_props
  end

  def update
    begin
      @bundle.is_bundle = true
      @bundle.native_type = Link::NATIVE_TYPE_BUNDLE
      @bundle.assign_attributes(bundle_permitted_params.except(
        :products, :custom_button_text_option, :custom_summary, :custom_attributes, :tags, :covers, :refund_policy, :product_refund_policy_enabled,
        :seller_refund_policy_enabled, :section_ids, :installment_plan)
      )
      @bundle.save_custom_button_text_option(bundle_permitted_params[:custom_button_text_option]) unless bundle_permitted_params[:custom_button_text_option].nil?
      @bundle.save_custom_summary(bundle_permitted_params[:custom_summary]) unless bundle_permitted_params[:custom_summary].nil?
      @bundle.save_custom_attributes(bundle_permitted_params[:custom_attributes]) unless bundle_permitted_params[:custom_attributes].nil?
      @bundle.save_tags!(bundle_permitted_params[:tags]) unless bundle_permitted_params[:tags].nil?
      @bundle.reorder_previews(bundle_permitted_params[:covers].map.with_index.to_h) if bundle_permitted_params[:covers].present?
      update_refund_policy
      update_installment_plan
      @bundle.save!
    rescue ActiveRecord::RecordNotSaved, ActiveRecord::RecordInvalid, Link::LinkInvalid => e
      Rails.logger.error("Bundle update failed: #{e.message}")
      redirect_to edit_bundle_product_path(@bundle.external_id),
                  inertia: inertia_errors_props,
                  alert: @bundle.errors.full_messages.first || e.message
      return
    end

    redirect_to edit_bundle_product_path(@bundle.external_id), notice: "Changes saved!", status: :see_other
  end

  private
    def update_refund_policy
      return if current_seller.account_level_refund_policy_enabled?

      @bundle.product_refund_policy_enabled = bundle_permitted_params[:product_refund_policy_enabled]
      if bundle_permitted_params[:refund_policy].present? && bundle_permitted_params[:product_refund_policy_enabled]
        @bundle.find_or_initialize_product_refund_policy.update!(bundle_permitted_params[:refund_policy])
      elsif @bundle.product_refund_policy_enabled == false && @bundle.product_refund_policy.present?
        @bundle.product_refund_policy.destroy
      end
    end

    def update_installment_plan
      return unless @bundle.eligible_for_installment_plans?

      if @bundle.installment_plan && bundle_permitted_params[:installment_plan].present?
        @bundle.installment_plan.assign_attributes(bundle_permitted_params[:installment_plan])
        return unless @bundle.installment_plan.changed?
      end

      @bundle.installment_plan&.destroy_if_no_payment_options!
      @bundle.reset_installment_plan

      if bundle_permitted_params[:installment_plan].present?
        @bundle.create_installment_plan!(bundle_permitted_params[:installment_plan])
      end
    end
end
