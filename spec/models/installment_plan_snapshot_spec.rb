# frozen_string_literal: true

require "spec_helper"

describe InstallmentPlanSnapshot do
  let(:subscription) { create(:subscription) }
  let(:payment_option) { create(:payment_option, subscription: subscription) }

  describe "associations" do
    it "belongs to payment_option" do
      snapshot = build(:installment_plan_snapshot, payment_option: payment_option)
      expect(snapshot.payment_option).to eq(payment_option)
    end

    it "belongs to original_offer_code" do
      offer_code = create(:offer_code)
      snapshot = build(:installment_plan_snapshot, payment_option: payment_option, original_offer_code: offer_code)
      expect(snapshot.original_offer_code).to eq(offer_code)
    end
  end

  describe "validations" do
    context "number_of_installments" do
      it "requires presence" do
        snapshot = build(:installment_plan_snapshot, payment_option: payment_option, number_of_installments: nil)
        expect(snapshot).not_to be_valid
        expect(snapshot.errors[:number_of_installments]).to include("can't be blank")
      end

      it "must be greater than 0" do
        snapshot = build(:installment_plan_snapshot, payment_option: payment_option, number_of_installments: 0)
        expect(snapshot).not_to be_valid
        expect(snapshot.errors[:number_of_installments]).to include("must be greater than 0")
      end

      it "must be an integer" do
        snapshot = build(:installment_plan_snapshot, payment_option: payment_option, number_of_installments: 3.5)
        expect(snapshot).not_to be_valid
        expect(snapshot.errors[:number_of_installments]).to include("must be an integer")
      end
    end

    context "recurrence" do
      it "requires presence" do
        snapshot = build(:installment_plan_snapshot, payment_option: payment_option, recurrence: nil)
        expect(snapshot).not_to be_valid
        expect(snapshot.errors[:recurrence]).to include("can't be blank")
      end
    end

    context "total_price_cents" do
      it "requires presence" do
        snapshot = build(:installment_plan_snapshot, payment_option: payment_option, total_price_cents: nil)
        expect(snapshot).not_to be_valid
        expect(snapshot.errors[:total_price_cents]).to include("can't be blank")
      end

      it "must be greater than 0" do
        snapshot = build(:installment_plan_snapshot, payment_option: payment_option, total_price_cents: 0)
        expect(snapshot).not_to be_valid
        expect(snapshot.errors[:total_price_cents]).to include("must be greater than 0")
      end

      it "must be an integer" do
        snapshot = build(:installment_plan_snapshot, payment_option: payment_option, total_price_cents: 100.5)
        expect(snapshot).not_to be_valid
        expect(snapshot.errors[:total_price_cents]).to include("must be an integer")
      end
    end

    context "payment_option uniqueness" do
      it "allows only one snapshot per payment_option" do
        create(:installment_plan_snapshot, payment_option: payment_option)
        duplicate = build(:installment_plan_snapshot, payment_option: payment_option)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:payment_option]).to include("has already been taken")
      end
    end

    context "valid snapshot" do
      it "is valid with all required attributes" do
        snapshot = build(:installment_plan_snapshot, payment_option: payment_option)
        expect(snapshot).to be_valid
      end
    end
  end

  describe "#calculate_installment_payment_price_cents" do
    context "when total divides evenly" do
      it "returns equal payments" do
        snapshot = create(:installment_plan_snapshot,
                          payment_option: payment_option,
                          number_of_installments: 3,
                          total_price_cents: 15000)

        payments = snapshot.calculate_installment_payment_price_cents
        expect(payments).to eq([5000, 5000, 5000])
        expect(payments.sum).to eq(15000)
      end
    end

    context "when total has remainder" do
      it "adds remainder to first payment" do
        snapshot = create(:installment_plan_snapshot,
                          payment_option: payment_option,
                          number_of_installments: 3,
                          total_price_cents: 10000)

        payments = snapshot.calculate_installment_payment_price_cents
        expect(payments).to eq([3334, 3333, 3333])
        expect(payments.sum).to eq(10000)
      end

      it "handles larger remainders correctly" do
        snapshot = create(:installment_plan_snapshot,
                          payment_option: payment_option,
                          number_of_installments: 3,
                          total_price_cents: 14700)

        payments = snapshot.calculate_installment_payment_price_cents
        expect(payments).to eq([4900, 4900, 4900])
        expect(payments.sum).to eq(14700)
      end
    end

    context "single installment" do
      it "returns full amount" do
        snapshot = create(:installment_plan_snapshot,
                          payment_option: payment_option,
                          number_of_installments: 1,
                          total_price_cents: 10000)

        payments = snapshot.calculate_installment_payment_price_cents
        expect(payments).to eq([10000])
      end
    end

    context "many installments" do
      it "handles 12 installments correctly" do
        snapshot = create(:installment_plan_snapshot,
                          payment_option: payment_option,
                          number_of_installments: 12,
                          total_price_cents: 12000)

        payments = snapshot.calculate_installment_payment_price_cents
        expect(payments).to eq([1000] * 12)
        expect(payments.sum).to eq(12000)
      end
    end
  end

  describe "#has_original_offer_code?" do
    it "returns true when original_offer_code_id is present" do
      snapshot = build(:installment_plan_snapshot, payment_option: payment_option, original_offer_code_id: 123)
      expect(snapshot.has_original_offer_code?).to be true
    end

    it "returns false when original_offer_code_id is nil" do
      snapshot = build(:installment_plan_snapshot, payment_option: payment_option, original_offer_code_id: nil)
      expect(snapshot.has_original_offer_code?).to be false
    end
  end

  describe "#original_offer_code_amount_off" do
    context "when no original offer code" do
      it "returns 0" do
        snapshot = build(:installment_plan_snapshot, payment_option: payment_option, original_offer_code_id: nil)
        expect(snapshot.original_offer_code_amount_off(1000)).to eq(0)
      end
    end

    context "with fixed amount offer code" do
      it "returns the fixed amount" do
        snapshot = build(:installment_plan_snapshot,
                         payment_option: payment_option,
                         original_offer_code_id: 123,
                         original_offer_code_amount_cents: 500,
                         original_offer_code_is_percent: false)
        expect(snapshot.original_offer_code_amount_off(1000)).to eq(500)
      end
    end

    context "with percentage offer code" do
      it "calculates percentage of price" do
        snapshot = build(:installment_plan_snapshot,
                         payment_option: payment_option,
                         original_offer_code_id: 123,
                         original_offer_code_amount_percentage: 25,
                         original_offer_code_is_percent: true)
        expect(snapshot.original_offer_code_amount_off(1000)).to eq(250)
      end

      it "rounds percentage calculations" do
        snapshot = build(:installment_plan_snapshot,
                         payment_option: payment_option,
                         original_offer_code_id: 123,
                         original_offer_code_amount_percentage: 33,
                         original_offer_code_is_percent: true)
        expect(snapshot.original_offer_code_amount_off(1000)).to eq(330)
      end
    end
  end
end
