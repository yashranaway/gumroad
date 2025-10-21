# frozen_string_literal: true

require "spec_helper"

describe Onetime::BackfillPaymentOptionInstallmentSnapshots do
  let(:seller) { create(:user) }
  let(:product) { create(:product, user: seller, price_cents: 14700) }
  let(:installment_plan) { create(:product_installment_plan, link: product, number_of_installments: 3, recurrence: "monthly") }
  let(:buyer) { create(:user, credit_card: create(:credit_card)) }

  describe ".perform" do
    it "creates snapshots for payment_options with installment plans but no snapshots" do
      purchase = create(:purchase,
                        link: product,
                        email: buyer.email,
                        is_original_subscription_purchase: true,
                        is_installment_payment: true,
                        installment_plan: installment_plan,
                        price_cents: 4900)

      subscription = purchase.subscription
      payment_option = subscription.last_payment_option

      # Simulate old record without snapshot
      payment_option.installment_plan_snapshot&.destroy

      expect(payment_option.reload.installment_plan_snapshot).to be_nil

      described_class.perform

      snapshot = payment_option.reload.installment_plan_snapshot
      expect(snapshot).to be_present
      expect(snapshot.number_of_installments).to eq(3)
      expect(snapshot.recurrence).to eq("monthly")
      expect(snapshot.total_price_cents).to eq(14700)
    end

    it "skips payment_options that already have snapshots" do
      purchase = create(:purchase,
                        link: product,
                        email: buyer.email,
                        is_original_subscription_purchase: true,
                        is_installment_payment: true,
                        installment_plan: installment_plan)

      payment_option = purchase.subscription.last_payment_option
      original_snapshot = payment_option.installment_plan_snapshot

      expect {
        described_class.perform
      }.not_to change { InstallmentPlanSnapshot.count }

      expect(payment_option.reload.installment_plan_snapshot).to eq(original_snapshot)
    end

    it "skips payment_options without installment plans" do
      subscription = create(:subscription, is_installment_plan: false)
      payment_option = create(:payment_option, subscription: subscription, installment_plan: nil)

      expect {
        described_class.perform
      }.not_to change { InstallmentPlanSnapshot.count }

      expect(payment_option.reload.installment_plan_snapshot).to be_nil
    end

    it "skips payment_options without original purchase" do
      subscription = create(:subscription, is_installment_plan: true, link: product)
      payment_option = create(:payment_option,
                              subscription: subscription,
                              installment_plan: installment_plan)

      # Ensure no original purchase exists
      subscription.purchases.destroy_all

      expect {
        described_class.perform
      }.not_to change { InstallmentPlanSnapshot.count }
    end

    it "handles errors gracefully and continues processing" do
      purchase1 = create(:purchase,
                         link: product,
                         email: buyer.email,
                         is_original_subscription_purchase: true,
                         is_installment_payment: true,
                         installment_plan: installment_plan)

      purchase2 = create(:purchase,
                         link: product,
                         email: "another@example.com",
                         is_original_subscription_purchase: true,
                         is_installment_payment: true,
                         installment_plan: installment_plan)

      payment_option1 = purchase1.subscription.last_payment_option
      payment_option2 = purchase2.subscription.last_payment_option

      payment_option1.installment_plan_snapshot&.destroy
      payment_option2.installment_plan_snapshot&.destroy

      # Stub first one to fail
      allow(InstallmentPlanSnapshot).to receive(:create!).and_call_original
      allow(InstallmentPlanSnapshot).to receive(:create!).with(hash_including(payment_option: payment_option1))
        .and_raise(StandardError.new("Test error"))

      expect(Rails.logger).to receive(:error).with(/Failed to backfill PaymentOption #{payment_option1.id}/)

      described_class.perform

      # First should fail, second should succeed
      expect(payment_option1.reload.installment_plan_snapshot).to be_nil
      expect(payment_option2.reload.installment_plan_snapshot).to be_present
    end

    it "processes multiple payment_options in batch" do
      purchases = 3.times.map do |i|
        create(:purchase,
               link: product,
               email: "buyer#{i}@example.com",
               is_original_subscription_purchase: true,
               is_installment_payment: true,
               installment_plan: installment_plan)
      end

      payment_options = purchases.map { |p| p.subscription.last_payment_option }
      payment_options.each { |po| po.installment_plan_snapshot&.destroy }

      expect {
        described_class.perform
      }.to change { InstallmentPlanSnapshot.count }.by(3)

      payment_options.each do |payment_option|
        expect(payment_option.reload.installment_plan_snapshot).to be_present
      end
    end
  end
end
