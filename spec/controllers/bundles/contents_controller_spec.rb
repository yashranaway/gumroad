# frozen_string_literal: true

require "spec_helper"
require "shared_examples/sellers_base_controller_concern"
require "shared_examples/authorize_called"

describe Bundles::ContentsController do
  let(:seller) { create(:named_seller, :eligible_for_service_products) }
  let(:bundle) { create(:product, :bundle, user: seller, price_cents: 2000) }

  include_context "with user signed in as admin for seller"

  describe "GET edit" do
    render_views

    it "renders the Content Edit Inertia page" do
      get :edit, params: { bundle_id: bundle.external_id }
      expect(response).to be_successful
      expect(response.body).to have_selector("title:contains('#{bundle.name}')", visible: false)
    end

    context "when the bundle doesn't exist" do
      it "returns 404" do
        expect { get :edit, params: { bundle_id: "" } }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "PATCH update" do
    let(:product) { create(:product, user: seller) }
    let(:versioned_product) { create(:product_with_digital_versions, user: seller) }
    let(:bundle_params) do
      {
        bundle_id: bundle.external_id,
        products: [
          {
            product_id: bundle.bundle_products.first.product.external_id,
            variant_id: nil,
            quantity: 3,
            position: 0,
          },
          {
            product_id: product.external_id,
            quantity: 1,
            position: 1,
          },
          {
            product_id: versioned_product.external_id,
            variant_id: versioned_product.alive_variants.first.external_id,
            quantity: 2,
            position: 2,
          }
        ]
      }
    end

    it "updates the bundle products" do
      patch :update, params: bundle_params
      bundle.reload

      expect(response).to redirect_to(edit_bundle_content_path(bundle.external_id))
      expect(flash[:notice]).to eq("Changes saved!")

      new_bundle_products = bundle.bundle_products.alive
      expect(new_bundle_products.first.product).to eq(bundle.bundle_products.first.product)
      expect(new_bundle_products.first.variant).to be_nil
      expect(new_bundle_products.first.quantity).to eq(3)

      expect(new_bundle_products.second.product).to eq(product)
      expect(new_bundle_products.second.quantity).to eq(1)

      expect(new_bundle_products.third.product).to eq(versioned_product)
      expect(new_bundle_products.third.variant).to eq(versioned_product.alive_variants.first)
      expect(new_bundle_products.third.quantity).to eq(2)
    end

    context "product is not a bundle" do
      let(:regular_product) { create(:product, user: seller) }

      it "converts it to a bundle" do
        patch :update, params: {
          bundle_id: regular_product.external_id,
          products: [{ product_id: product.external_id, quantity: 1, position: 0 }]
        }

        regular_product.reload
        expect(regular_product.is_bundle).to eq(true)
        expect(regular_product.native_type).to eq(Link::NATIVE_TYPE_BUNDLE)
      end
    end

    context "when the bundle doesn't exist" do
      it "returns 404" do
        expect { patch :update, params: { bundle_id: "" } }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "POST update_purchases_content" do
    context "when bundle has outdated purchases" do
      before do
        bundle.update!(has_outdated_purchases: true)
      end

      it "queues the job and redirects" do
        expect(UpdateBundlePurchasesContentJob).to receive(:perform_async).with(bundle.id)

        post :update_purchases_content, params: { bundle_id: bundle.external_id }

        expect(response).to redirect_to(edit_bundle_content_path(bundle.external_id))
        expect(flash[:notice]).to include("queued")
      end
    end

    context "when bundle has no outdated purchases" do
      it "redirects with error" do
        post :update_purchases_content, params: { bundle_id: bundle.external_id }

        expect(response).to redirect_to(edit_bundle_content_path(bundle.external_id))
        expect(flash[:alert]).to include("no purchases")
      end
    end
  end
end
