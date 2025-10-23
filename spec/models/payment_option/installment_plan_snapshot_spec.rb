# frozen_string_literal: true

require "spec_helper"

describe "PaymentOption", :vcr do
  let(:seller) { create(:user) }
  let(:product) { create(:product, user: seller, price_cents: 14700) }
  let(:installment_plan) { create(:product_installment_plan, link: product, number_of_installments: 3, recurrence: "monthly") }
  let!(:buyer) { create(:user, credit_card: create(:credit_card)) }

  before do
    allow(Stripe::PaymentMethod).to receive(:create).and_return(
      double("Stripe::PaymentMethod", id: "pm_test_123", card: double("card", fingerprint: "fp_test_123"))
    )
  end

  describe "snapshotting on creation" do
    it "creates InstallmentPlanSnapshot with number_of_installments, recurrence, and total_price_cents" do
      purchase = create(:purchase,
                        link: product,
                        email: buyer.email,
                        is_original_subscription_purchase: true,
                        is_installment_payment: true,
                        installment_plan: installment_plan)

      subscription = purchase.subscription
      payment_option = subscription.last_payment_option
      snapshot = payment_option.installment_plan_snapshot

      expect(snapshot).to be_present
      expect(snapshot.number_of_installments).to eq(3)
      expect(snapshot.recurrence).to eq("monthly")
      expect(snapshot.total_price_cents).to eq(14700)
    end
  end

  describe "price protection" do
    it "protects existing installment schedules when product price increases" do
      purchase = create(:purchase,
                        link: product,
                        email: buyer.email,
                        price_cents: 4900,
                        is_original_subscription_purchase: true,
                        is_installment_payment: true,
                        installment_plan: installment_plan,
                        purchaser: buyer)

      subscription = purchase.subscription
      expect(purchase.price_cents).to eq(4900)

      product.update!(price_cents: 19700)
      installment_plan.reload

      travel_to(1.month.from_now) do
        RecurringChargeWorker.new.perform(subscription.id)
      end

      second_purchase = subscription.purchases.successful.last
      expect(second_purchase.price_cents).to eq(4900)

      travel_to(2.months.from_now) do
        RecurringChargeWorker.new.perform(subscription.id)
      end

      third_purchase = subscription.purchases.successful.last
      expect(third_purchase.price_cents).to eq(4900)
    end

    it "protects existing installment schedules when product price decreases" do
      purchase = create(:purchase,
                        link: product,
                        email: buyer.email,
                        price_cents: 4900,
                        is_original_subscription_purchase: true,
                        is_installment_payment: true,
                        installment_plan: installment_plan,
                        purchaser: buyer)

      subscription = purchase.subscription
      expect(purchase.price_cents).to eq(4900)

      product.update!(price_cents: 10000)
      installment_plan.reload

      travel_to(1.month.from_now) do
        RecurringChargeWorker.new.perform(subscription.id)
      end

      second_purchase = subscription.purchases.successful.last
      expect(second_purchase.price_cents).to eq(4900)
    end
  end

  describe "installment count protection" do
    it "protects existing schedules when number_of_installments changes from 3 to 2" do
      purchase = create(:purchase,
                        link: product,
                        email: buyer.email,
                        price_cents: 4900,
                        is_original_subscription_purchase: true,
                        is_installment_payment: true,
                        installment_plan: installment_plan,
                        purchaser: buyer)

      subscription = purchase.subscription
      payment_option = subscription.last_payment_option
      snapshot = payment_option.installment_plan_snapshot

      expect(snapshot.number_of_installments).to eq(3)
      expect(purchase.price_cents).to eq(4900)

      installment_plan.update!(number_of_installments: 2)

      travel_to(1.month.from_now) do
        RecurringChargeWorker.new.perform(subscription.id)
      end

      second_purchase = subscription.purchases.successful.last
      expect(second_purchase.price_cents).to eq(4900)
      expect(subscription.purchases.successful.count).to eq(2)

      travel_to(2.months.from_now) do
        RecurringChargeWorker.new.perform(subscription.id)
      end

      third_purchase = subscription.purchases.successful.last
      expect(third_purchase.price_cents).to eq(4900)
      expect(subscription.purchases.successful.count).to eq(3)

      expect(subscription.charges_completed?).to be(true)
    end

    it "protects existing schedules when number_of_installments changes from 3 to 5" do
      purchase = create(:purchase,
                        link: product,
                        email: buyer.email,
                        price_cents: 4900,
                        is_original_subscription_purchase: true,
                        is_installment_payment: true,
                        installment_plan: installment_plan,
                        purchaser: buyer)

      subscription = purchase.subscription
      installment_plan.update!(number_of_installments: 5)

      travel_to(1.month.from_now) do
        RecurringChargeWorker.new.perform(subscription.id)
      end

      travel_to(2.months.from_now) do
        RecurringChargeWorker.new.perform(subscription.id)
      end

      expect(subscription.purchases.successful.count).to eq(3)
      expect(subscription.charges_completed?).to be(true)
    end
  end

  describe "recurrence protection" do
    it "protects existing schedules when recurrence changes" do
      subscription = create(:subscription, is_installment_plan: true, link: product)
      payment_option = create(:payment_option,
                              subscription: subscription,
                              installment_plan: installment_plan)

      InstallmentPlanSnapshot.create!(
        payment_option: payment_option,
        number_of_installments: 3,
        recurrence: "monthly",
        total_price_cents: 14700
      )

      expect(payment_option.installment_plan_snapshot.recurrence).to eq("monthly")

      installment_plan.update!(recurrence: "yearly")

      expect(payment_option.subscription.recurrence).to eq("monthly")
    end
  end

  describe "backwards compatibility" do
    it "falls back to live ProductInstallmentPlan for existing records without snapshot" do
      subscription = create(:subscription, is_installment_plan: true, link: product)
      payment_option = create(:payment_option,
                              subscription: subscription,
                              installment_plan: installment_plan)

      # Simulate old record without snapshot
      payment_option.installment_plan_snapshot&.destroy

      purchase = create(:purchase,
                        link: product,
                        subscription: subscription,
                        is_installment_payment: true,
                        is_original_subscription_purchase: true)

      installment_amount = purchase.send(:calculate_installment_payment_price_cents, 14700)

      expect(installment_amount).to eq(4900)
    end
  end
end
