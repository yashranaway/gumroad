# frozen_string_literal: true

require "spec_helper"

describe Refund::BalanceLoadIntegration do
  let(:seller) { create(:user) }
  let(:purchase) { create(:purchase, seller:) }
  let(:refund) { create(:refund, purchase:, seller:) }

  before do
    Flipper.enable(:balance_load_for_refunds, seller)
  end

  after do
    Flipper.disable(:balance_load_for_refunds, seller)
  end

  describe "#check_and_load_balance_if_needed" do
    context "when feature flag is disabled" do
      before do
        Flipper.disable(:balance_load_for_refunds, seller)
      end

      it "returns true without loading balance" do
        expect(refund.check_and_load_balance_if_needed(1000)).to be true
      end
    end

    context "when seller has sufficient balance" do
      before do
        create(:balance, user: seller, amount_cents: 5000)
      end

      it "returns true without loading balance" do
        expect {
          refund.check_and_load_balance_if_needed(1000)
        }.not_to change { BalanceLoad.count }

        expect(refund.check_and_load_balance_if_needed(1000)).to be true
      end
    end

    context "when seller has insufficient balance" do
      let(:card) { create(:balance_load_credit_card, :default, user: seller) }

      before do
        create(:balance, user: seller, amount_cents: 500)
        card
      end

      it "loads balance for the difference" do
        allow_any_instance_of(BalanceLoading::ChargeService).to receive(:charge).and_call_original

        expect {
          refund.check_and_load_balance_if_needed(1000)
        }.to change { BalanceLoad.count }.by(1)

        balance_load = BalanceLoad.last
        expect(balance_load.amount_cents).to eq(500)
        expect(balance_load.refund).to eq(refund)
      end

      it "returns true on successful charge" do
        allow_any_instance_of(BalanceLoading::ChargeService).to receive(:charge).and_return(
          create(:balance_load, :pending)
        )

        expect(refund.check_and_load_balance_if_needed(1000)).to be true
      end

      it "returns false and adds error on charge failure" do
        allow_any_instance_of(BalanceLoading::ChargeService).to receive(:charge)
          .and_raise(BalanceLoading::ChargeService::ChargeError.new("Card declined"))

        expect(refund.check_and_load_balance_if_needed(1000)).to be false
        expect(refund.errors[:base]).to include(/Unable to load balance/)
      end

      it "returns false on insufficient amount error" do
        allow_any_instance_of(BalanceLoading::ChargeService).to receive(:charge)
          .and_raise(BalanceLoading::ChargeService::InsufficientAmountError.new("Too small"))

        expect(refund.check_and_load_balance_if_needed(1000)).to be false
        expect(refund.errors[:base]).to include("Too small")
      end
    end

    context "when seller has no payment method" do
      before do
        create(:balance, user: seller, amount_cents: 500)
      end

      it "returns false and adds error" do
        allow_any_instance_of(BalanceLoading::ChargeService).to receive(:charge)
          .and_raise(BalanceLoading::ChargeService::ChargeError.new("No payment method available"))

        expect(refund.check_and_load_balance_if_needed(1000)).to be false
        expect(refund.errors[:base]).to be_present
      end
    end
  end
end
