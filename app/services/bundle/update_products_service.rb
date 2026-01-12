# frozen_string_literal: true

class Bundle::UpdateProductsService
  def initialize(bundle:, products:)
    @bundle = bundle
    @products = products
  end

  def perform
    bundle_products = @bundle.bundle_products.includes(:product)

    bundle_products.each do |bundle_product|
      new_bundle_product = @products.find { _1[:product_id] == bundle_product.product.external_id }
      if new_bundle_product.present?
        bundle_product.update(
          variant: BaseVariant.find_by_external_id(new_bundle_product[:variant_id]),
          quantity: new_bundle_product[:quantity],
          deleted_at: nil,
          position: new_bundle_product[:position]
        )
        @products.delete(new_bundle_product)
        update_has_outdated_purchases
      else
        bundle_product.mark_deleted!
      end
    end

    update_has_outdated_purchases if @products.present?

    @products.each do |new_bundle_product|
      product = Link.find_by_external_id!(new_bundle_product[:product_id])
      variant = BaseVariant.find_by_external_id(new_bundle_product[:variant_id])

      @bundle.bundle_products.create!(
        product:,
        variant:,
        quantity: new_bundle_product[:quantity],
        position: new_bundle_product[:position]
      )
    end
  end

  private
    def update_has_outdated_purchases
      return if @bundle.has_outdated_purchases?

      @bundle.has_outdated_purchases = true if @bundle.successful_sales_count > 0
    end
end
