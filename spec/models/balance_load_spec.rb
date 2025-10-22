# frozen_string_literal: true

require "spec_helper"

describe BalanceLoad do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:balance_load_credit_card) }
    it { is_expected.to belong_to(:refund).optional }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:amount_cents) }
    it { is_expected.to validate_presence_of(:currency) }
    it { is_expected.to validate_presence_of(:status) }

    it "validates amount_cents is positive" do
      balance_load = build(:balance_load, amount_cents: -100)
      expect(balance_load).not_to be_valid
      expect(balance_load.errors[:amount_cents]).to be_present
    end

    it "validates currency is USD" do
      balance_load = build(:balance_load, currency: "EUR")
      expect(balance_load).not_to be_valid
    end

    it "validates status is valid" do
      balance_load = build(:balance_load, status: "invalid")
      expect(balance_load).not_to be_valid
    end
  end

  describe "scopes" do
    let!(:pending_load) { create(:balance_load, :pending) }
    let!(:successful_load) { create(:balance_load, :successful) }
    let!(:failed_load) { create(:balance_load, :failed) }

    describe ".pending" do
      it "returns only pending loads" do
        expect(described_class.pending).to eq([pending_load])
      end
    end

    describe ".successful" do
      it "returns only successful loads" do
        expect(described_class.successful).to eq([successful_load])
      end
    end

    describe ".failed" do
      it "returns only failed loads" do
        expect(described_class.failed).to eq([failed_load])
      end
    end

    describe ".recent" do
      it "orders by created_at descending" do
        expect(described_class.recent.first).to eq(failed_load)
      end
    end
  end

  describe "#mark_successful!" do
    it "updates status and stripe_charge_id" do
      balance_load = create(:balance_load, :pending)
      balance_load.mark_successful!("ch_test123")

      expect(balance_load.status).to eq("successful")
      expect(balance_load.stripe_charge_id).to eq("ch_test123")
      expect(balance_load.error_message).to be_nil
    end
  end

  describe "#mark_failed!" do
    it "updates status and error_message" do
      balance_load = create(:balance_load, :pending)
      balance_load.mark_failed!("Card declined")

      expect(balance_load.status).to eq("failed")
      expect(balance_load.error_message).to eq("Card declined")
    end
  end

  describe "status predicates" do
    it "returns correct status" do
      pending_load = create(:balance_load, :pending)
      successful_load = create(:balance_load, :successful)
      failed_load = create(:balance_load, :failed)

      expect(pending_load.pending?).to be true
      expect(successful_load.successful?).to be true
      expect(failed_load.failed?).to be true
    end
  end

  describe "#amount_dollars" do
    it "converts cents to dollars" do
      balance_load = create(:balance_load, amount_cents: 1234)
      expect(balance_load.amount_dollars).to eq(12.34)
    end
  end
end
