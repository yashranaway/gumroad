# frozen_string_literal: true

require "spec_helper"
require "shared_examples/sellers_base_controller_concern"
require "shared_examples/authorize_called"

describe Bundles::ProductsController do
  let(:seller) { create(:named_seller, :eligible_for_service_products) }
  let(:bundle) { create(:product, :bundle, user: seller, price_cents: 2000) }

  include_context "with user signed in as admin for seller"

  describe "GET edit" do
    render_views

    it "renders the Product Edit Inertia page and sets the title to the bundle's name" do
      expect(BundlePresenter).to receive(:new).with(bundle:).and_call_original
      get :edit, params: { bundle_id: bundle.external_id }
      expect(response.body).to have_selector("title:contains('#{bundle.name}')", visible: false)
      expect(response).to be_successful
    end

    context "when the bundle doesn't exist" do
      it "returns 404" do
        expect { get :edit, params: { bundle_id: "" } }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "product is membership" do
      let(:product) { create(:membership_product) }

      it "returns 404" do
        expect { get :edit, params: { bundle_id: product.external_id } }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "product has variants" do
      let(:product) { create(:product_with_digital_versions) }

      it "returns 404" do
        expect { get :edit, params: { bundle_id: product.external_id } }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "PATCH update" do
    let(:product) { create(:product, user: seller) }
    let(:asset_previews) { create_list(:asset_preview, 2, link: bundle) }
    let(:bundle_params) do
      {
        bundle_id: bundle.external_id,
        name: "New name",
        description: "New description",
        custom_permalink: "new-permalink",
        price_cents: 1000,
        customizable_price: true,
        suggested_price_cents: 2000,
        custom_button_text_option: "buy_this_prompt",
        custom_summary: "Custom summary",
        custom_attributes: [{ "name" => "Detail 1", "value" => "Value 1" }],
        covers: [asset_previews.second.guid, asset_previews.first.guid],
        max_purchase_count: 10,
        quantity_enabled: true,
        should_show_sales_count: true,
        is_epublication: true,
      }
    end

    it "updates the bundle" do
      expect do
        patch :update, params: bundle_params
        bundle.reload
      end.to change { bundle.name }.from("Bundle").to("New name")
      .and change { bundle.description }.from("This is a bundle of products").to("New description")
      .and change { bundle.custom_permalink }.from(nil).to("new-permalink")
      .and change { bundle.price_cents }.from(2000).to(1000)
      .and change { bundle.customizable_price? }.from(false).to(true)
      .and change { bundle.suggested_price_cents }.from(nil).to(2000)
      .and change { bundle.custom_button_text_option }.from(nil).to("buy_this_prompt")
      .and change { bundle.custom_attributes }.from([]).to([{ "name" => "Detail 1", "value" => "Value 1" }])
      .and change { bundle.custom_summary }.from(nil).to("Custom summary")
      .and change { bundle.display_asset_previews.map(&:id) }.from([asset_previews.first.id, asset_previews.second.id]).to([asset_previews.second.id, asset_previews.first.id])
      .and change { bundle.max_purchase_count }.from(nil).to(10)
      .and change { bundle.quantity_enabled }.from(false).to(true)
      .and change { bundle.should_show_sales_count }.from(false).to(true)
      .and change { bundle.is_epublication }.from(false).to(true)

      expect(response).to redirect_to(edit_bundle_product_path(bundle.external_id))
      expect(flash[:notice]).to eq("Changes saved!")
    end

    context "when the bundle doesn't exist" do
      it "returns 404" do
        expect { patch :update, params: { bundle_id: "" } }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
