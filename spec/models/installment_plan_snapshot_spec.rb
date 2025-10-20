# frozen_string_literal: true

require "spec_helper"

describe InstallmentPlanSnapshot do
  let(:payment_option) { create(:payment_option) }

  describe "validations" do
    it "validates presence of number_of_installments" do
      snapshot = InstallmentPlanSnapshot.new(
        payment_option: payment_option,
        recurrence: "monthly",
        total_price_cents: 10000
      )
      expect(snapshot.valid?).to eq(false)
      expect(snapshot.errors[:number_of_installments]).to be_present
    end

    it "validates number_of_installments is greater than 0" do
      snapshot = InstallmentPlanSnapshot.new(
        payment_option: payment_option,
        number_of_installments: 0,
        recurrence: "monthly",
        total_price_cents: 10000
      )
      expect(snapshot.valid?).to eq(false)
      expect(snapshot.errors[:number_of_installments]).to include("must be greater than 0")
    end

    it "validates number_of_installments is an integer" do
      snapshot = InstallmentPlanSnapshot.new(
        payment_option: payment_option,
        number_of_installments: 3.5,
        recurrence: "monthly",
        total_price_cents: 10000
      )
      expect(snapshot.valid?).to eq(false)
      expect(snapshot.errors[:number_of_installments]).to include("must be an integer")
    end

    it "validates presence of recurrence" do
      snapshot = InstallmentPlanSnapshot.new(
        payment_option: payment_option,
        number_of_installments: 3,
        total_price_cents: 10000
      )
      expect(snapshot.valid?).to eq(false)
      expect(snapshot.errors[:recurrence]).to be_present
    end

    it "validates presence of total_price_cents" do
      snapshot = InstallmentPlanSnapshot.new(
        payment_option: payment_option,
        number_of_installments: 3,
        recurrence: "monthly"
      )
      expect(snapshot.valid?).to eq(false)
      expect(snapshot.errors[:total_price_cents]).to be_present
    end

    it "validates total_price_cents is greater than 0" do
      snapshot = InstallmentPlanSnapshot.new(
        payment_option: payment_option,
        number_of_installments: 3,
        recurrence: "monthly",
        total_price_cents: 0
      )
      expect(snapshot.valid?).to eq(false)
      expect(snapshot.errors[:total_price_cents]).to include("must be greater than 0")
    end

    it "validates total_price_cents is an integer" do
      snapshot = InstallmentPlanSnapshot.new(
        payment_option: payment_option,
        number_of_installments: 3,
        recurrence: "monthly",
        total_price_cents: 100.5
      )
      expect(snapshot.valid?).to eq(false)
      expect(snapshot.errors[:total_price_cents]).to include("must be an integer")
    end

    it "validates uniqueness of payment_option" do
      InstallmentPlanSnapshot.create!(
        payment_option: payment_option,
        number_of_installments: 3,
        recurrence: "monthly",
        total_price_cents: 10000
      )

      duplicate = InstallmentPlanSnapshot.new(
        payment_option: payment_option,
        number_of_installments: 5,
        recurrence: "yearly",
        total_price_cents: 20000
      )
      expect(duplicate.valid?).to eq(false)
      expect(duplicate.errors[:payment_option]).to include("has already been taken")
    end

    it "is valid with all required attributes" do
      snapshot = InstallmentPlanSnapshot.new(
        payment_option: payment_option,
        number_of_installments: 3,
        recurrence: "monthly",
        total_price_cents: 10000
      )
      expect(snapshot.valid?).to eq(true)
    end
  end

  describe "#calculate_installment_payment_price_cents" do
    it "divides total evenly when no remainder" do
      snapshot = InstallmentPlanSnapshot.create!(
        payment_option: payment_option,
        number_of_installments: 3,
        recurrence: "monthly",
        total_price_cents: 15000
      )

      payments = snapshot.calculate_installment_payment_price_cents
      expect(payments).to eq([5000, 5000, 5000])
    end

    it "puts remainder in first payment" do
      snapshot = InstallmentPlanSnapshot.create!(
        payment_option: payment_option,
        number_of_installments: 3,
        recurrence: "monthly",
        total_price_cents: 10000
      )

      payments = snapshot.calculate_installment_payment_price_cents
      expect(payments).to eq([3334, 3333, 3333])
      expect(payments.sum).to eq(10000)
    end

    it "handles single installment" do
      snapshot = InstallmentPlanSnapshot.create!(
        payment_option: payment_option,
        number_of_installments: 1,
        recurrence: "monthly",
        total_price_cents: 10000
      )

      payments = snapshot.calculate_installment_payment_price_cents
      expect(payments).to eq([10000])
    end
  end
end
