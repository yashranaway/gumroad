# frozen_string_literal: true

require "spec_helper"

describe BalanceLoading::PaymentMethodService do
  let(:user) { create(:user, stripe_customer_id: "cus_test123") }
  let(:service) { described_class.new(user) }

  describe "#attach_payment_method" do
    let(:payment_method_id) { "pm_test123" }
    let(:payment_method) do
      double(
        "Stripe::PaymentMethod",
        customer: nil,
        card: double(last4: "4242", brand: "visa", exp_month: 12, exp_year: 2025)
      )
    end

    before do
      allow(Stripe::PaymentMethod).to receive(:retrieve).with(payment_method_id).and_return(payment_method)
      allow(Stripe::PaymentMethod).to receive(:attach)
    end

    it "attaches payment method to customer" do
      expect(Stripe::PaymentMethod).to receive(:attach).with(
        payment_method_id,
        { customer: user.stripe_customer_id }
      )

      service.attach_payment_method(payment_method_id)
    end

    it "creates balance_load_credit_card record" do
      expect {
        service.attach_payment_method(payment_method_id)
      }.to change { user.balance_load_credit_cards.count }.by(1)

      card = user.balance_load_credit_cards.last
      expect(card.stripe_payment_method_id).to eq(payment_method_id)
      expect(card.last4).to eq("4242")
      expect(card.brand).to eq("visa")
    end

    it "sets as default if specified" do
      card = service.attach_payment_method(payment_method_id, set_as_default: true)
      expect(card.is_default).to be true
    end

    it "sets as default if no other cards exist" do
      card = service.attach_payment_method(payment_method_id)
      expect(card.is_default).to be true
    end

    it "raises error if payment method belongs to another customer" do
      allow(payment_method).to receive(:customer).and_return("cus_other")

      expect {
        service.attach_payment_method(payment_method_id)
      }.to raise_error(BalanceLoading::PaymentMethodService::AttachmentError, /belongs to another customer/)
    end

    it "raises error on Stripe failure" do
      allow(Stripe::PaymentMethod).to receive(:attach).and_raise(Stripe::CardError.new("Card error", nil))

      expect {
        service.attach_payment_method(payment_method_id)
      }.to raise_error(BalanceLoading::PaymentMethodService::AttachmentError)
    end
  end

  describe "#detach_payment_method" do
    let(:card) { create(:balance_load_credit_card, user:) }

    before do
      allow(Stripe::PaymentMethod).to receive(:detach)
    end

    context "when card has no balance loads" do
      it "detaches from Stripe and destroys record" do
        expect(Stripe::PaymentMethod).to receive(:detach).with(card.stripe_payment_method_id)

        expect {
          service.detach_payment_method(card)
        }.to change { BalanceLoadCreditCard.count }.by(-1)
      end
    end

    context "when card has balance loads" do
      before do
        create(:balance_load, balance_load_credit_card: card)
      end

      it "soft deletes the card" do
        service.detach_payment_method(card)

        expect(card.reload.deleted_at).not_to be_nil
      end
    end

    it "raises error on Stripe failure" do
      allow(Stripe::PaymentMethod).to receive(:detach).and_raise(Stripe::StripeError.new("Error"))

      expect {
        service.detach_payment_method(card)
      }.to raise_error(BalanceLoading::PaymentMethodService::DetachmentError)
    end
  end

  describe "#set_default_payment_method" do
    it "sets card as default" do
      card = create(:balance_load_credit_card, user:, is_default: false)

      service.set_default_payment_method(card)

      expect(card.reload.is_default).to be true
    end
  end
end
