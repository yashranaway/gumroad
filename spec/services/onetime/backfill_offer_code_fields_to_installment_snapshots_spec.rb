# frozen_string_literal: true

require "spec_helper"

describe Onetime::BackfillOfferCodeFieldsToInstallmentSnapshots do
  let(:seller) { create(:user) }
  let(:product) { create(:product, user: seller, price_cents: 14700) }
  let(:installment_plan) { create(:product_installment_plan, link: product, number_of_installments: 3, recurrence: "monthly") }

  describe ".perform" do
    context "when snapshot has offer_code_id but missing new fields" do
      it "updates with offer code data from the offer code record" do
        offer_code = create(:offer_code, code: "SAVE20", products: [product], amount_cents: 200, currency_type: "usd", duration_in_months: 6)
        subscription = create(:subscription, link: product, user: seller)
        payment_option = create(:payment_option, subscription: subscription, installment_plan: installment_plan)
        snapshot = create(:installment_plan_snapshot,
                          payment_option: payment_option,
                          number_of_installments: 3,
                          recurrence: "monthly",
                          total_price_cents: 14700,
                          original_offer_code_id: offer_code.id,
                          original_offer_code_amount_cents: 200,
                          original_offer_code_is_percent: false,
                          original_offer_code_code: nil,
                          original_offer_code_currency: nil,
                          original_offer_code_duration_in_months: nil)

        described_class.perform

        snapshot.reload
        expect(snapshot.original_offer_code_code).to eq("SAVE20")
        expect(snapshot.original_offer_code_currency).to eq("usd")
        expect(snapshot.original_offer_code_duration_in_months).to eq(6)
      end
    end

    context "when snapshot has no offer_code_id but original purchase has offer code" do
      it "backfills all offer code fields from the original purchase" do
        offer_code = create(:offer_code, code: "PERCENT25", products: [product], amount_percentage: 25, currency_type: "usd")
        subscription = create(:subscription, link: product, user: seller)
        subscription.update_column(:flags, subscription.flags | 64) # Set is_installment_plan flag
        payment_option = create(:payment_option, subscription: subscription, installment_plan: installment_plan)

        original_purchase = build(:purchase,
                                  link: product,
                                  subscription: subscription,
                                  offer_code: offer_code,
                                  is_original_subscription_purchase: true,
                                  is_installment_payment: true,
                                  price_cents: 4900)
        original_purchase.save!(validate: false)

        snapshot = create(:installment_plan_snapshot,
                          payment_option: payment_option,
                          number_of_installments: 3,
                          recurrence: "monthly",
                          total_price_cents: 14700,
                          original_offer_code_id: nil)

        described_class.perform

        snapshot.reload
        expect(snapshot.original_offer_code_id).to eq(offer_code.id)
        expect(snapshot.original_offer_code_amount_percentage).to eq(25)
        expect(snapshot.original_offer_code_is_percent).to be true
        expect(snapshot.original_offer_code_code).to eq("PERCENT25")
        expect(snapshot.original_offer_code_currency).to eq("usd")
      end
    end

    context "when snapshot already has all offer code data" do
      it "does not query for offer code" do
        offer_code = create(:offer_code, code: "EXISTING", products: [product], amount_cents: 100)
        subscription = create(:subscription, link: product, user: seller)
        payment_option = create(:payment_option, subscription: subscription, installment_plan: installment_plan)
        create(:installment_plan_snapshot,
               payment_option: payment_option,
               number_of_installments: 3,
               recurrence: "monthly",
               total_price_cents: 14700,
               original_offer_code_id: offer_code.id,
               original_offer_code_amount_cents: 100,
               original_offer_code_is_percent: false,
               original_offer_code_code: "EXISTING",
               original_offer_code_currency: "usd")

        expect { described_class.perform }.not_to raise_error
      end
    end

    context "when offer code has been deleted" do
      it "skips the snapshot gracefully" do
        subscription = create(:subscription, link: product, user: seller)
        payment_option = create(:payment_option, subscription: subscription, installment_plan: installment_plan)
        snapshot = create(:installment_plan_snapshot,
                          payment_option: payment_option,
                          number_of_installments: 3,
                          recurrence: "monthly",
                          total_price_cents: 14700,
                          original_offer_code_id: 99999,
                          original_offer_code_amount_cents: 200,
                          original_offer_code_is_percent: false,
                          original_offer_code_code: nil)

        expect { described_class.perform }.not_to raise_error

        snapshot.reload
        expect(snapshot.original_offer_code_code).to be_nil
      end
    end

    context "when subscription is not an installment plan" do
      it "skips the snapshot in backfill_snapshots_from_purchases" do
        subscription = create(:subscription, link: product, user: seller, is_installment_plan: false)
        payment_option = create(:payment_option, subscription: subscription, installment_plan: nil)
        snapshot = create(:installment_plan_snapshot,
                          payment_option: payment_option,
                          number_of_installments: 3,
                          recurrence: "monthly",
                          total_price_cents: 14700,
                          original_offer_code_id: nil)

        described_class.perform

        snapshot.reload
        expect(snapshot.original_offer_code_id).to be_nil
      end
    end

    context "when error occurs during processing" do
      it "logs the error and continues" do
        offer_code = create(:offer_code, code: "TEST", products: [product], amount_cents: 100)
        subscription = create(:subscription, link: product, user: seller)
        payment_option = create(:payment_option, subscription: subscription, installment_plan: installment_plan)
        create(:installment_plan_snapshot,
               payment_option: payment_option,
               number_of_installments: 3,
               recurrence: "monthly",
               total_price_cents: 14700,
               original_offer_code_id: offer_code.id,
               original_offer_code_code: nil)

        allow_any_instance_of(InstallmentPlanSnapshot).to receive(:update!).and_raise(StandardError.new("Test error"))
        expect(Rails.logger).to receive(:error).with(/Failed to backfill snapshot/)

        expect { described_class.perform }.not_to raise_error
      end
    end
  end
end
