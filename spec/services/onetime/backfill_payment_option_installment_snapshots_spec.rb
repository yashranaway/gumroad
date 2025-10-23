# frozen_string_literal: true

require "spec_helper"

describe Onetime::BackfillPaymentOptionInstallmentSnapshots do
  let(:seller) { create(:user) }
  let(:product) { create(:product, user: seller, price_cents: 14700) }
  let(:installment_plan) { create(:product_installment_plan, link: product, number_of_installments: 3, recurrence: "monthly") }

  describe ".perform" do
    it "creates snapshots for payment_options with installment plans but no snapshots" do
      subscription = create(:subscription, is_installment_plan: true, link: product)
      subscription.payment_options.destroy_all
      payment_option = create(:payment_option,
                              subscription: subscription,
                              installment_plan: installment_plan)
      create(:purchase,
             link: product,
             subscription: subscription,
             is_original_subscription_purchase: true,
             is_installment_payment: true,
             price_cents: 14700)

      expect(payment_option.reload.installment_plan_snapshot).to be_nil

      described_class.perform

      snapshot = payment_option.reload.installment_plan_snapshot
      expect(snapshot).to be_present
      expect(snapshot.number_of_installments).to eq(3)
      expect(snapshot.recurrence).to eq("monthly")
      expect(snapshot.total_price_cents).to eq(14700)
    end

    it "skips payment_options that already have snapshots" do
      subscription = create(:subscription, is_installment_plan: true, link: product)
      subscription.payment_options.destroy_all
      payment_option = create(:payment_option,
                              subscription: subscription,
                              installment_plan: installment_plan)
      original_snapshot = create(:installment_plan_snapshot,
                                 payment_option: payment_option,
                                 number_of_installments: 3,
                                 recurrence: "monthly",
                                 total_price_cents: 14700)

      expect do
        described_class.perform
      end.not_to change { InstallmentPlanSnapshot.count }

      expect(payment_option.reload.installment_plan_snapshot).to eq(original_snapshot)
    end

    it "skips payment_options without installment plans" do
      subscription = create(:subscription, is_installment_plan: false)
      payment_option = create(:payment_option, subscription: subscription, installment_plan: nil)

      expect do
        described_class.perform
      end.not_to change { InstallmentPlanSnapshot.count }

      expect(payment_option.reload.installment_plan_snapshot).to be_nil
    end

    it "skips payment_options without original purchase" do
      subscription = create(:subscription, is_installment_plan: true, link: product)
      subscription.payment_options.destroy_all
      create(:payment_option,
             subscription: subscription,
             installment_plan: installment_plan)

      # Ensure no original purchase exists
      subscription.purchases.destroy_all

      expect do
        described_class.perform
      end.not_to change { InstallmentPlanSnapshot.count }
    end

    it "handles errors gracefully and continues processing" do
      subscription1 = create(:subscription, is_installment_plan: true, link: product)
      subscription1.payment_options.destroy_all
      payment_option1 = create(:payment_option,
                               subscription: subscription1,
                               installment_plan: installment_plan)
      create(:purchase,
             link: product,
             subscription: subscription1,
             is_original_subscription_purchase: true,
             is_installment_payment: true,
             price_cents: 14700)

      subscription2 = create(:subscription, is_installment_plan: true, link: product)
      subscription2.payment_options.destroy_all
      payment_option2 = create(:payment_option,
                               subscription: subscription2,
                               installment_plan: installment_plan)
      create(:purchase,
             link: product,
             subscription: subscription2,
             is_original_subscription_purchase: true,
             is_installment_payment: true,
             price_cents: 14700)

      allow(InstallmentPlanSnapshot).to receive(:create!).and_call_original
      allow(InstallmentPlanSnapshot).to receive(:create!).with(hash_including(payment_option: payment_option1))
        .and_raise(StandardError.new("Test error"))

      expect(Rails.logger).to receive(:error).with(/Failed to backfill PaymentOption #{payment_option1.id}/)

      described_class.perform

      expect(payment_option1.reload.installment_plan_snapshot).to be_nil
      expect(payment_option2.reload.installment_plan_snapshot).to be_present
    end

    it "processes multiple payment_options in batch" do
      payment_options = 3.times.map do
        subscription = create(:subscription, is_installment_plan: true, link: product)
        subscription.payment_options.destroy_all
        payment_option = create(:payment_option,
                                subscription: subscription,
                                installment_plan: installment_plan)
        create(:purchase,
               link: product,
               subscription: subscription,
               is_original_subscription_purchase: true,
               is_installment_payment: true,
               price_cents: 14700)
        payment_option
      end

      expect do
        described_class.perform
      end.to change { InstallmentPlanSnapshot.count }.by(3)

      payment_options.each do |payment_option|
        expect(payment_option.reload.installment_plan_snapshot).to be_present
      end
    end
  end
end
