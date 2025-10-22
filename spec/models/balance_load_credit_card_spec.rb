# frozen_string_literal: true

require "spec_helper"

describe BalanceLoadCreditCard do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:balance_loads).dependent(:restrict_with_error) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:stripe_payment_method_id) }
    it { is_expected.to validate_presence_of(:last4) }
    it { is_expected.to validate_presence_of(:brand) }
    it { is_expected.to validate_presence_of(:exp_month) }
    it { is_expected.to validate_presence_of(:exp_year) }

    it "validates last4 length" do
      card = build(:balance_load_credit_card, last4: "123")
      expect(card).not_to be_valid
      expect(card.errors[:last4]).to be_present
    end

    it "validates exp_month range" do
      card = build(:balance_load_credit_card, exp_month: 13)
      expect(card).not_to be_valid
    end

    it "validates exp_year is not in the past" do
      card = build(:balance_load_credit_card, exp_year: Time.current.year - 1)
      expect(card).not_to be_valid
    end

    it "validates only one default card per user" do
      user = create(:user)
      create(:balance_load_credit_card, :default, user:)
      
      second_card = build(:balance_load_credit_card, :default, user:)
      expect(second_card).not_to be_valid
      expect(second_card.errors[:is_default]).to be_present
    end
  end

  describe "scopes" do
    let(:user) { create(:user) }
    let!(:active_card) { create(:balance_load_credit_card, user:) }
    let!(:deleted_card) { create(:balance_load_credit_card, :deleted, user:) }
    let!(:default_card) { create(:balance_load_credit_card, :default, user:) }

    describe ".alive" do
      it "returns only non-deleted cards" do
        expect(described_class.alive).to include(active_card, default_card)
        expect(described_class.alive).not_to include(deleted_card)
      end
    end

    describe ".default_cards" do
      it "returns only default cards that are alive" do
        expect(described_class.default_cards).to eq([default_card])
      end
    end
  end

  describe "#expired?" do
    it "returns true for expired cards" do
      card = create(:balance_load_credit_card, :expired)
      expect(card.expired?).to be true
    end

    it "returns false for valid cards" do
      card = create(:balance_load_credit_card, exp_month: 12, exp_year: Time.current.year + 1)
      expect(card.expired?).to be false
    end
  end

  describe "#expiring_soon?" do
    it "returns true for cards expiring within specified months" do
      card = create(:balance_load_credit_card, :expiring_soon)
      expect(card.expiring_soon?(months: 1)).to be true
    end

    it "returns false for cards expiring later" do
      card = create(:balance_load_credit_card, exp_month: 12, exp_year: Time.current.year + 2)
      expect(card.expiring_soon?(months: 1)).to be false
    end
  end

  describe "#display_name" do
    it "returns formatted card name" do
      card = create(:balance_load_credit_card, brand: "visa", last4: "4242")
      expect(card.display_name).to eq("visa ****4242")
    end
  end

  describe "setting default card" do
    it "unsets other default cards when setting a new default" do
      user = create(:user)
      first_card = create(:balance_load_credit_card, :default, user:)
      second_card = create(:balance_load_credit_card, user:)

      second_card.update!(is_default: true)

      expect(first_card.reload.is_default).to be false
      expect(second_card.reload.is_default).to be true
    end
  end
end
