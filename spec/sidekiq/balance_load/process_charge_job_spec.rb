# frozen_string_literal: true

require "spec_helper"

describe BalanceLoading::ProcessChargeJob do
  let(:user) { create(:user, stripe_customer_id: "cus_test123") }
  let(:card) { create(:balance_load_credit_card, user:) }
  let(:balance_load) { create(:balance_load, :pending, user:, balance_load_credit_card: card) }

  describe "#perform" do
    it "processes the charge" do
      charge_service = instance_double(BalanceLoading::ChargeService)
      allow(BalanceLoading::ChargeService).to receive(:new).with(user).and_return(charge_service)
      expect(charge_service).to receive(:process_charge).with(balance_load)

      described_class.new.perform(balance_load.id)
    end

    it "notifies Bugsnag on charge error" do
      allow_any_instance_of(BalanceLoading::ChargeService).to receive(:process_charge)
        .and_raise(BalanceLoading::ChargeService::ChargeError.new("Test error"))

      expect(Bugsnag).to receive(:notify)

      expect {
        described_class.new.perform(balance_load.id)
      }.to raise_error(BalanceLoading::ChargeService::ChargeError)
    end
  end

  describe "sidekiq options" do
    it "uses default queue" do
      expect(described_class.sidekiq_options_hash["queue"]).to eq(:default)
    end

    it "has retry enabled" do
      expect(described_class.sidekiq_options_hash["retry"]).to eq(3)
    end

    it "uses until_executed lock" do
      expect(described_class.sidekiq_options_hash["lock"]).to eq(:until_executed)
    end
  end
end
