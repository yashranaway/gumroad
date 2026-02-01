# frozen_string_literal: true

require "spec_helper"
require "shared_examples/sellers_base_controller_concern"
require "shared_examples/authorize_called"

describe CommunitiesController do
  let(:seller) { create(:user) }
  let(:pundit_user) { SellerContext.new(user: seller, seller:) }
  let(:product) { create(:product, user: seller, community_chat_enabled: true) }
  let!(:community) { create(:community, seller:, resource: product) }

  include_context "with user signed in as admin for seller"

  before do
    Feature.activate_user(:communities, seller)
  end

  describe "GET index" do
    it_behaves_like "authorize called for action", :get, :index do
      let(:record) { Community }
    end

    context "when seller is logged in" do
      before do
        sign_in seller
      end

      it "renders the page" do
        get :index
        expect(response).to be_successful
        expect(controller.send(:page_title)).to eq("Communities")
      end

      it "returns unauthorized response if the :communities feature flag is disabled" do
        Feature.deactivate_user(:communities, seller)

        get :index

        expect(response).to redirect_to dashboard_path
        expect(flash[:alert]).to eq("You are not allowed to perform this action.")
      end
    end
  end

  describe "GET show" do
    it_behaves_like "authorize called for action", :get, :show do
      let(:record) { community }
      let(:request_params) { { seller_id: seller.external_id, community_id: community.external_id } }
    end

    context "when seller is logged in" do
      before do
        sign_in seller
      end

      it "renders the page with selected community" do
        get :show, params: { seller_id: seller.external_id, community_id: community.external_id }
        expect(response).to be_successful
        expect(controller.send(:page_title)).to eq("Communities")
      end

      it "returns unauthorized response if the :communities feature flag is disabled" do
        Feature.deactivate_user(:communities, seller)

        get :show, params: { seller_id: seller.external_id, community_id: community.external_id }

        expect(response).to redirect_to dashboard_path
        expect(flash[:alert]).to eq("You are not allowed to perform this action.")
      end

      it "returns 404 when community does not exist" do
        expect do
          get :show, params: { seller_id: seller.external_id, community_id: "nonexistent" }
        end.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "returns 404 when seller_id does not match community seller" do
        other_seller = create(:user)
        expect do
          get :show, params: { seller_id: other_seller.external_id, community_id: community.external_id }
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when buyer is logged in" do
      let(:buyer) { create(:user) }
      let!(:purchase) { create(:free_purchase, seller:, purchaser: buyer, link: product) }

      before do
        sign_in buyer
      end

      it "renders the page with selected community" do
        get :show, params: { seller_id: seller.external_id, community_id: community.external_id }
        expect(response).to be_successful
      end

      it "returns unauthorized if buyer does not have access" do
        purchase.destroy!

        get :show, params: { seller_id: seller.external_id, community_id: community.external_id }

        expect(response).to redirect_to dashboard_path
        expect(flash[:alert]).to eq("You are not allowed to perform this action.")
      end
    end
  end
end
