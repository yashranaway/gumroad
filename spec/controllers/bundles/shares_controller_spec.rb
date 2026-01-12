# frozen_string_literal: true

require "spec_helper"
require "shared_examples/sellers_base_controller_concern"
require "shared_examples/authorize_called"

describe Bundles::SharesController do
  let(:seller) { create(:named_seller, :eligible_for_service_products) }
  let(:bundle) { create(:product, :bundle, user: seller, price_cents: 2000) }

  include_context "with user signed in as admin for seller"

  describe "GET edit" do
    render_views

    context "when the bundle is published" do
      let(:bundle) { create(:product, :bundle, user: seller, price_cents: 2000, purchase_disabled_at: nil) }

      it "renders the Share Edit Inertia page" do
        get :edit, params: { bundle_id: bundle.external_id }
        expect(response).to be_successful
        expect(response.body).to have_selector("title:contains('#{bundle.name}')", visible: false)
      end
    end

    context "when the bundle is not published" do
      let(:bundle) { create(:product, :bundle, user: seller, price_cents: 2000, purchase_disabled_at: Time.current) }

      it "redirects to edit_content with alert" do
        get :edit, params: { bundle_id: bundle.external_id }
        expect(response).to redirect_to(edit_bundle_content_path(bundle.external_id))
        expect(flash[:alert]).to include("publish")
      end
    end

    context "when the bundle doesn't exist" do
      it "returns 404" do
        expect { get :edit, params: { bundle_id: "" } }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "PATCH update" do
    let(:bundle) { create(:product, :bundle, user: seller, price_cents: 2000, purchase_disabled_at: nil) }
    let(:profile_section1) { create(:seller_profile_products_section, seller:, shown_products: [bundle.id]) }
    let(:profile_section2) { create(:seller_profile_products_section, seller:) }
    let(:bundle_params) do
      {
        bundle_id: bundle.external_id,
        taxonomy_id: 1,
        tags: ["tag1", "tag2"],
        display_product_reviews: false,
        is_adult: true,
        section_ids: [profile_section2.external_id],
      }
    end

    it "updates the bundle share settings" do
      expect do
        patch :update, params: bundle_params
        bundle.reload
      end.to change { bundle.taxonomy_id }.from(nil).to(1)
      .and change { bundle.tags.pluck(:name) }.from([]).to(["tag1", "tag2"])
      .and change { bundle.display_product_reviews }.from(true).to(false)
      .and change { bundle.is_adult }.from(false).to(true)
      .and change { profile_section1.reload.shown_products }.from([bundle.id]).to([])
      .and change { profile_section2.reload.shown_products }.from([]).to([bundle.id])

      expect(response).to redirect_to(edit_bundle_share_path(bundle.external_id))
      expect(flash[:notice]).to eq("Changes saved!")
    end

    context "when the bundle is not published" do
      let(:bundle) { create(:product, :bundle, user: seller, price_cents: 2000, purchase_disabled_at: Time.current) }

      it "redirects to edit_content with alert" do
        patch :update, params: { bundle_id: bundle.external_id }
        expect(response).to redirect_to(edit_bundle_content_path(bundle.external_id))
        expect(flash[:alert]).to include("publish")
      end
    end

    context "when the bundle doesn't exist" do
      it "returns 404" do
        expect { patch :update, params: { bundle_id: "" } }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
