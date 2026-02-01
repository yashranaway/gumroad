# frozen_string_literal: true

require "spec_helper"
require "shared_examples/sellers_base_controller_concern"
require "shared_examples/authorize_called"

describe Communities::LastReadChatMessagesController do
  let(:seller) { create(:user) }
  let(:product) { create(:product, user: seller, community_chat_enabled: true) }
  let(:pundit_user) { SellerContext.new(user: seller, seller:) }
  let!(:community) { create(:community, resource: product, seller:) }

  include_context "with user signed in as admin for seller"

  before do
    Feature.activate_user(:communities, seller)
  end

  describe "POST create" do
    it_behaves_like "authorize called for action", :post, :create do
      let(:record) { community }
      let(:policy_method) { :show? }
      let(:request_params) { { community_id: community.external_id, message_id: "message123" } }
    end

    context "when seller is logged in" do
      before do
        sign_in seller
      end

      it "returns unauthorized response if the :communities feature flag is disabled" do
        Feature.deactivate_user(:communities, seller)

        post :create, params: { community_id: community.external_id, message_id: "message123" }

        expect(response).to redirect_to dashboard_path
        expect(flash[:alert]).to eq("You are not allowed to perform this action.")
      end

      it "raises routing error when community is not found" do
        expect do
          post :create, params: { community_id: "nonexistent", message_id: "message123" }
        end.to raise_error(ActionController::RoutingError)
      end

      it "raises routing error when message is not found" do
        expect do
          post :create, params: { community_id: community.external_id, message_id: "nonexistent" }
        end.to raise_error(ActionController::RoutingError)
      end

      it "marks a message as read and redirects" do
        create(:community_chat_message, community:, user: seller, created_at: 3.minutes.ago)
        message2 = create(:community_chat_message, community:, user: seller, created_at: 2.minutes.ago)
        create(:community_chat_message, community:, user: seller, created_at: 1.minute.ago)

        post :create, params: { community_id: community.external_id, message_id: message2.external_id }

        expect(response).to redirect_to community_path(seller_id: seller.external_id, community_id: community.external_id)
      end

      it "creates a new last read record" do
        message = create(:community_chat_message, community:, user: seller)

        expect do
          post :create, params: { community_id: community.external_id, message_id: message.external_id }
        end.to change { LastReadCommunityChatMessage.count }.by(1)

        last_read = LastReadCommunityChatMessage.last
        expect(last_read.user).to eq(seller)
        expect(last_read.community).to eq(community)
        expect(last_read.community_chat_message).to eq(message)
      end

      it "updates existing last read record when marking a newer message as read" do
        message1 = create(:community_chat_message, community:, user: seller, created_at: 2.minutes.ago)
        message2 = create(:community_chat_message, community:, user: seller, created_at: 1.minute.ago)
        last_read = create(:last_read_community_chat_message, user: seller, community:, community_chat_message: message1)

        expect do
          expect do
            post :create, params: { community_id: community.external_id, message_id: message2.external_id }
          end.to change { last_read.reload.community_chat_message }.to(message2)
        end.not_to change { LastReadCommunityChatMessage.count }
      end

      it "does not update last read record when marking an older message as read" do
        message1 = create(:community_chat_message, community:, user: seller, created_at: 2.minutes.ago)
        message2 = create(:community_chat_message, community:, user: seller, created_at: 1.minute.ago)
        create(:last_read_community_chat_message, user: seller, community:, community_chat_message: message2)

        expect do
          post :create, params: { community_id: community.external_id, message_id: message1.external_id }
        end.not_to change { LastReadCommunityChatMessage.count }

        expect(response).to redirect_to community_path(seller_id: seller.external_id, community_id: community.external_id)
      end
    end

    context "when buyer is logged in" do
      let(:buyer) { create(:user) }
      let!(:purchase) { create(:free_purchase, seller:, purchaser: buyer, link: product) }

      before do
        sign_in buyer
      end

      it "marks a message as read and redirects" do
        create(:community_chat_message, community:, user: seller, created_at: 3.minutes.ago)
        message2 = create(:community_chat_message, community:, user: seller, created_at: 2.minutes.ago)
        create(:community_chat_message, community:, user: seller, created_at: 1.minute.ago)

        post :create, params: { community_id: community.external_id, message_id: message2.external_id }

        expect(response).to redirect_to community_path(seller_id: seller.external_id, community_id: community.external_id)
      end

      it "creates a new last read record" do
        message = create(:community_chat_message, community:, user: seller)

        expect do
          post :create, params: { community_id: community.external_id, message_id: message.external_id }
        end.to change { LastReadCommunityChatMessage.count }.by(1)

        last_read = LastReadCommunityChatMessage.last
        expect(last_read.user).to eq(buyer)
        expect(last_read.community).to eq(community)
        expect(last_read.community_chat_message).to eq(message)
      end

      it "updates existing last read record when marking a newer message as read" do
        message1 = create(:community_chat_message, community:, user: seller, created_at: 2.minutes.ago)
        message2 = create(:community_chat_message, community:, user: seller, created_at: 1.minute.ago)
        last_read = create(:last_read_community_chat_message, user: buyer, community:, community_chat_message: message1)

        expect do
          expect do
            post :create, params: { community_id: community.external_id, message_id: message2.external_id }
          end.to change { last_read.reload.community_chat_message }.to(message2)
        end.not_to change { LastReadCommunityChatMessage.count }
      end

      it "does not update last read record when marking an older message as read" do
        message1 = create(:community_chat_message, community:, user: seller, created_at: 2.minutes.ago)
        message2 = create(:community_chat_message, community:, user: seller, created_at: 1.minute.ago)
        create(:last_read_community_chat_message, user: buyer, community:, community_chat_message: message2)

        expect do
          post :create, params: { community_id: community.external_id, message_id: message1.external_id }
        end.not_to change { LastReadCommunityChatMessage.count }

        expect(response).to redirect_to community_path(seller_id: seller.external_id, community_id: community.external_id)
      end
    end
  end
end
