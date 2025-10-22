# frozen_string_literal: true

require "spec_helper"

describe BalanceLoading::ChargeService do
  let(:user) { create(:user, stripe_customer_id: "cus_test123") }
  let(:card) { create(:balance_load_credit_card, :default, user:) }
  let(:service) { described_class.new(user) }

  describe "#charge" do
    it "creates a pending balance_load record" do
      expect {
        service.charge(1000, balance_load_credit_card: card)
      }.to change { BalanceLoad.count }.by(1)

      balance_load = BalanceLoad.last
      expect(balance_load.status).to eq("pending")
      expect(balance_load.amount_cents).to eq(1000)
      expect(balance_load.user).to eq(user)
      expect(balance_load.balance_load_credit_card).to eq(card)
    end

    it "enqueues ProcessChargeJob" do
      expect {
        service.charge(1000, balance_load_credit_card: card)
      }.to change { BalanceLoading::ProcessChargeJob.jobs.size }.by(1)
    end

    it "uses default card if none specified" do
      balance_load = service.charge(1000)
      expect(balance_load.balance_load_credit_card).to eq(card)
    end

    it "links to refund if provided" do
      refund = create(:refund)
      balance_load = service.charge(1000, balance_load_credit_card: card, refund:)
      expect(balance_load.refund).to eq(refund)
    end

    it "raises error if no payment method available" do
      user_without_card = create(:user)
      service_without_card = described_class.new(user_without_card)

      expect {
        service_without_card.charge(1000)
      }.to raise_error(BalanceLoading::ChargeService::ChargeError, /No payment method available/)
    end

    it "raises error if card is expired" do
      expired_card = create(:balance_load_credit_card, :expired, :default, user:)

      expect {
        service.charge(1000, balance_load_credit_card: expired_card)
      }.to raise_error(BalanceLoading::ChargeService::ChargeError, /expired/)
    end

    it "raises error if amount is below minimum" do
      expect {
        service.charge(50, balance_load_credit_card: card)
      }.to raise_error(BalanceLoading::ChargeService::InsufficientAmountError)
    end
  end

  describe "#process_charge" do
    let(:balance_load) { create(:balance_load, :pending, user:, balance_load_credit_card: card) }
    let(:stripe_charge) { double("Stripe::Charge", id: "ch_test123") }

    before do
      allow(Stripe::Charge).to receive(:create).and_return(stripe_charge)
    end

    it "creates Stripe charge with correct parameters" do
      expect(Stripe::Charge).to receive(:create).with(
        hash_including(
          amount: balance_load.amount_cents,
          currency: "usd",
          customer: user.stripe_customer_id,
          payment_method: card.stripe_payment_method_id,
          confirm: true,
          off_session: true
        )
      )

      service.process_charge(balance_load)
    end

    it "marks balance_load as successful" do
      service.process_charge(balance_load)

      expect(balance_load.reload.status).to eq("successful")
      expect(balance_load.stripe_charge_id).to eq("ch_test123")
    end

    it "creates Balance record" do
      expect {
        service.process_charge(balance_load)
      }.to change { Balance.count }.by(1)

      balance = Balance.last
      expect(balance.user).to eq(user)
      expect(balance.amount_cents).to eq(balance_load.amount_cents)
      expect(balance.balance_type).to eq("balance_load")
    end

    it "handles card errors" do
      allow(Stripe::Charge).to receive(:create).and_raise(
        Stripe::CardError.new("Card declined", nil, code: "card_declined")
      )

      expect {
        service.process_charge(balance_load)
      }.to raise_error(BalanceLoading::ChargeService::ChargeError, /Card declined/)

      expect(balance_load.reload.status).to eq("failed")
      expect(balance_load.error_message).to eq("Card declined")
    end

    it "handles Stripe errors" do
      allow(Stripe::Charge).to receive(:create).and_raise(Stripe::StripeError.new("API error"))

      expect {
        service.process_charge(balance_load)
      }.to raise_error(BalanceLoading::ChargeService::ChargeError)

      expect(balance_load.reload.status).to eq("failed")
    end

    it "does not process already successful charges" do
      successful_load = create(:balance_load, :successful, user:, balance_load_credit_card: card)

      expect(Stripe::Charge).not_to receive(:create)
      service.process_charge(successful_load)
    end

    it "does not process already failed charges" do
      failed_load = create(:balance_load, :failed, user:, balance_load_credit_card: card)

      expect(Stripe::Charge).not_to receive(:create)
      service.process_charge(failed_load)
    end
  end
end
