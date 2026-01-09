# frozen_string_literal: true

require "spec_helper"
require "shared_examples/sellers_base_controller_concern"
require "shared_examples/authorize_called"
require "inertia_rails/rspec"

describe Bundles::ShareController, inertia: true do
  let(:seller) { create(:named_seller, :eligible_for_service_products) }
  let(:bundle) { create(:product, :bundle, user: seller, price_cents: 2000) }

  include_context "with user signed in as admin for seller"

  describe "GET edit" do
    it "renders the ShareTab Inertia component when tab is share" do
      get :edit, params: { id: bundle.external_id }
      expect(response).to be_successful
      expect(inertia.component).to eq("Bundles/ShareTab")
      expect(inertia.props).to have_key(:bundle)
      expect(inertia.props).to have_key(:tab)
      expect(inertia.props[:tab]).to eq("share")
      expect(assigns(:title)).to eq(bundle.name)
    end
  end

  describe "PUT update" do
    let(:profile_section1) { create(:seller_profile_products_section, seller:, shown_products: [bundle.id]) }
    let(:profile_section2) { create(:seller_profile_products_section, seller:) }

    it_behaves_like "authorize called for action", :put, :update do
      let(:policy_klass) { LinkPolicy }
      let(:record) { bundle }
      let(:request_params) { { id: bundle.external_id } }
    end

    it "updates section_ids and redirects" do
      expect do
        put :update, params: {
          id: bundle.external_id,
          section_ids: [profile_section2.external_id]
        }
        bundle.reload
      end.to change { profile_section1.reload.shown_products }.from([bundle.id]).to([])
      .and change { profile_section2.reload.shown_products }.from([]).to([bundle.id])

      expect(response).to redirect_to(bundles_edit_share_path(bundle.external_id))
      expect(flash[:notice]).to eq("Changes saved!")
    end
  end
end
