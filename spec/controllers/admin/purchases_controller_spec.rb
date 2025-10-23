# frozen_string_literal: true

require "spec_helper"
require "shared_examples/admin_base_controller_concern"

describe Admin::PurchasesController, :vcr do
  it_behaves_like "inherits from Admin::BaseController"

  before do
    @admin_user = create(:admin_user)
    sign_in @admin_user
  end

  describe "#show" do
    before do
      @purchase = create(:purchase)
    end

    it "raises ActionController::RoutingError when purchase is not found" do
      expect { get :show, params: { id: "invalid-id" } }.to raise_error(ActionController::RoutingError)
    end

    it "finds the purchase correctly when loaded via external id" do
      expect(Purchase).not_to receive(:find_by_stripe_transaction_id)
      expect(Purchase).to receive(:find_by_external_id).and_call_original
      get :show, params: { id: @purchase.external_id }

      expect(assigns(:purchase)).to eq(@purchase)
      assert_response :success
    end

    it "finds the purchase correctly when loaded via id" do
      expect(Purchase).not_to receive(:find_by_stripe_transaction_id)
      expect(Purchase).not_to receive(:find_by_external_id)
      get :show, params: { id: @purchase.id }

      expect(assigns(:purchase)).to eq(@purchase)
      assert_response :success
    end

    it "finds the purchase correctly when loaded via numeric external id" do
      expect(Purchase).to receive(:find_by_external_id_numeric).and_call_original
      get :show, params: { id: @purchase.external_id_numeric }

      expect(assigns(:purchase)).to eq(@purchase)
      assert_response :success
    end

    it "finds the purchase correctly when loaded via stripe_transaction_id" do
      expect(Purchase).to receive(:find_by_stripe_transaction_id).and_call_original
      get :show, params: { id: @purchase.stripe_transaction_id }

      expect(assigns(:purchase)).to eq(@purchase)
      assert_response :success
    end
  end

  describe "POST refund_for_fraud" do
    before do
      @purchase = create(:purchase_in_progress, chargeable: create(:chargeable), purchaser: create(:user))
      @purchase.process!
      @purchase.mark_successful!
    end

    it "refunds the purchase and blocks the buyer" do
      comment_content = "Buyer blocked by Admin (#{@admin_user.email})"
      expect do
        post :refund_for_fraud, params: { id: @purchase.id }

        expect(@purchase.reload.stripe_refunded).to be(true)
        expect(@purchase.buyer_blocked?).to eq(true)
        expect(response).to be_successful
        expect(response.parsed_body["success"]).to be(true)
      end.to change { @purchase.comments.where(content: comment_content, comment_type: "note", author_id: @admin_user.id).count }.by(1)
       .and change { @purchase.purchaser.comments.where(content: comment_content, comment_type: "note", author_id: @admin_user.id, purchase: @purchase).count }.by(1)
    end
  end

  describe "POST refund_taxes_only" do
    before do
      @purchase = create(:purchase_in_progress, chargeable: create(:chargeable), purchaser: create(:user))
      @purchase.process!
      @purchase.mark_successful!
    end

    it "successfully refunds taxes when refundable taxes are available" do
      allow_any_instance_of(Purchase).to receive(:refund_gumroad_taxes!).with(refunding_user_id: @admin_user.id, note: nil, business_vat_id: nil).and_return(true)

      post :refund_taxes_only, params: { id: @purchase.id }

      expect(response).to be_successful
      expect(response.parsed_body["success"]).to be(true)
    end

    it "includes note and business_vat_id when provided" do
      allow_any_instance_of(Purchase).to receive(:refund_gumroad_taxes!).with(refunding_user_id: @admin_user.id, note: "Tax exemption request", business_vat_id: "VAT123456").and_return(true)

      post :refund_taxes_only, params: {
        id: @purchase.id,
        note: "Tax exemption request",
        business_vat_id: "VAT123456"
      }

      expect(response).to be_successful
      expect(response.parsed_body["success"]).to be(true)
    end

    it "returns error when tax refund fails" do
      allow_any_instance_of(Purchase).to receive(:refund_gumroad_taxes!).with(refunding_user_id: @admin_user.id, note: nil, business_vat_id: nil).and_return(false)
      allow_any_instance_of(Purchase).to receive(:errors).and_return(
        double(full_messages: double(to_sentence: "Tax already refunded and Invalid tax amount"))
      )

      post :refund_taxes_only, params: { id: @purchase.id }

      expect(response).to be_successful
      expect(response.parsed_body["success"]).to be(false)
      expect(response.parsed_body["message"]).to eq("Tax already refunded and Invalid tax amount")
    end

    it "raises error when purchase is not found" do
      expect { post :refund_taxes_only, params: { id: "invalid-id" } }.to raise_error(ActionController::RoutingError)
    end
  end

  describe "POST resend_receipt" do
    before do
      @purchase = create(:purchase_in_progress, chargeable: create(:chargeable))
      @purchase.process!
      @purchase.mark_successful!
    end

    it "resends receipt without changing email" do
      original_email = @purchase.email

      post :resend_receipt, params: { id: @purchase.id, resend_receipt: { email_address: "" } }

      expect(response).to be_successful
      expect(response.parsed_body["success"]).to be(true)
      expect(@purchase.reload.email).to eq(original_email)
      expect(SendPurchaseReceiptJob).to have_enqueued_sidekiq_job(@purchase.id).on("critical")
    end

    it "updates email and resends receipt" do
      new_email = "newemail@example.com"

      post :resend_receipt, params: { id: @purchase.id, resend_receipt: { email_address: new_email } }

      expect(response).to be_successful
      expect(response.parsed_body["success"]).to be(true)
      expect(@purchase.reload.email).to eq(new_email)
      expect(SendPurchaseReceiptJob).to have_enqueued_sidekiq_job(@purchase.id).on("critical")
    end

    it "attaches purchase to user when email matches existing user" do
      existing_user = create(:user, email: "existing@example.com")

      post :resend_receipt, params: { id: @purchase.id, resend_receipt: { email_address: existing_user.email } }

      expect(response).to be_successful
      expect(@purchase.reload.purchaser).to eq(existing_user)
    end

    it "updates original_purchase email when purchase has subscription" do
      subscription = create(:subscription)
      original_purchase = create(:purchase, email: "old@example.com", is_original_subscription_purchase: true, subscription: subscription)
      recurring_purchase = create(:purchase, email: "old@example.com", subscription: subscription)
      new_email = "new@example.com"

      post :resend_receipt, params: { id: recurring_purchase.id, resend_receipt: { email_address: new_email } }

      expect(response).to be_successful
      expect(recurring_purchase.reload.email).to eq(new_email)
      expect(subscription.reload.original_purchase.email).to eq(new_email)
    end

    it "does not update original_purchase email if already matches" do
      subscription = create(:subscription)
      original_purchase = create(:purchase, email: "same@example.com", is_original_subscription_purchase: true, subscription: subscription)
      recurring_purchase = create(:purchase, email: "old@example.com", subscription: subscription)

      expect(original_purchase).not_to receive(:save)

      post :resend_receipt, params: { id: recurring_purchase.id, resend_receipt: { email_address: "same@example.com" } }

      expect(response).to be_successful
    end

    it "handles purchase without subscription" do
      new_email = "new@example.com"

      post :resend_receipt, params: { id: @purchase.id, resend_receipt: { email_address: new_email } }

      expect(response).to be_successful
      expect(@purchase.reload.email).to eq(new_email)
    end
  end

  describe "POST undelete" do
    before do
      @purchase = create(:purchase, purchaser: create(:user), is_deleted_by_buyer: true)
    end

    it "undeletes the purchase and creates comments" do
      comment_content = "Purchase undeleted by Admin (#{@admin_user.email})"
      expect do
        post :undelete, params: { id: @purchase.id }

        expect(@purchase.reload.is_deleted_by_buyer).to be(false)
        expect(response).to be_successful
        expect(response.parsed_body["success"]).to be(true)
      end.to change { @purchase.comments.where(content: comment_content, comment_type: "note", author_id: @admin_user.id).count }.by(1)
       .and change { @purchase.purchaser.comments.where(content: comment_content, comment_type: "note", author_id: @admin_user.id, purchase: @purchase).count }.by(1)
    end

    it "handles purchase that is already undeleted" do
      @purchase.update!(is_deleted_by_buyer: false)

      expect do
        post :undelete, params: { id: @purchase.id }

        expect(@purchase.reload.is_deleted_by_buyer).to be(false)
        expect(response).to be_successful
        expect(response.parsed_body["success"]).to be(true)
      end.not_to change { @purchase.comments.count }
    end

    it "handles purchase without purchaser" do
      @purchase.update!(purchaser: nil)
      comment_content = "Purchase undeleted by Admin (#{@admin_user.email})"

      expect do
        post :undelete, params: { id: @purchase.id }

        expect(@purchase.reload.is_deleted_by_buyer).to be(false)
        expect(response).to be_successful
        expect(response.parsed_body["success"]).to be(true)
      end.to change { @purchase.comments.where(content: comment_content, comment_type: "note", author_id: @admin_user.id).count }.by(1)
    end

    it "raises error when purchase is not found" do
      expect { post :undelete, params: { id: "invalid-id" } }.to raise_error(ActionController::RoutingError)
    end
  end
end
