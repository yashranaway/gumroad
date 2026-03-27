# frozen_string_literal: true

require "spec_helper"

describe Bundle::UpdateProductsService do
  let(:seller) { create(:named_seller) }
  let(:bundle) { create(:product, :bundle, user: seller, price_cents: 2000) }

  describe "#perform" do
    context "when a soft-deleted bundle product's product later gains variants" do
      let(:product_a) { create(:product, user: seller) }
      let(:product_b) { create(:product, user: seller) }

      it "succeeds without revalidating the stale deleted row" do
        bundle_product_a = create(:bundle_product, bundle: bundle, product: product_a)
        bundle_product_a.mark_deleted!

        category = create(:variant_category, title: "Versions", link: product_a)
        create(:variant, variant_category: category, name: "Version 1")
        create(:variant, variant_category: category, name: "Version 2")
        product_a.reload

        products_payload = [
          { product_id: product_b.external_id, variant_id: nil, quantity: 1, position: 0 }
        ]

        bundle.bundle_products.alive.each(&:mark_deleted!)

        result = described_class.new(bundle: bundle, products: products_payload).perform

        alive_products = result.bundle_products.alive
        expect(alive_products.map(&:product)).to eq([product_b])
      end
    end

    context "when an alive bundle product's product later gains variants and the row is removed" do
      let(:product_a) { create(:product, user: seller) }
      let(:product_b) { create(:product, user: seller) }

      it "succeeds and soft-deletes the now-invalid row without raising" do
        bundle_product_a = create(:bundle_product, bundle: bundle, product: product_a, variant: nil)

        category = create(:variant_category, title: "Versions", link: product_a)
        create(:variant, variant_category: category, name: "Version 1")
        create(:variant, variant_category: category, name: "Version 2")
        product_a.reload

        expect(bundle_product_a).not_to be_valid

        products_payload = [
          { product_id: product_b.external_id, variant_id: nil, quantity: 1, position: 0 }
        ]

        result = described_class.new(bundle: bundle, products: products_payload).perform

        bundle_product_a.reload
        expect(bundle_product_a).to be_deleted

        alive_products = result.bundle_products.alive
        expect(alive_products.map(&:product)).to eq([product_b])
      end
    end
  end
end
