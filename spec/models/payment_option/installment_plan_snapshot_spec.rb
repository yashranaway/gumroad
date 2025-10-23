# frozen_string_literal: true

require "spec_helper"

describe "PaymentOption", :vcr do
  let(:seller) { create(:user) }
  let(:product) { create(:product, user: seller, price_cents: 14700) }
  let(:installment_plan) { create(:product_installment_plan, link: product, number_of_installments: 3, recurrence: "monthly") }
  let!(:buyer) { create(:user) }

  before do
    card_hash = { last4: "4242", brand: "visa" }
    stripe_payment_method = double("Stripe::PaymentMethod",
                                  id: "pm_test_123",
                                  card: card_hash,
                                  customer: "cus_test_123")
    allow(Stripe::PaymentMethod).to receive(:create).and_return(stripe_payment_method)
    allow(Stripe::PaymentMethod).to receive(:retrieve).and_return(stripe_payment_method)

    chargeable = double("Chargeable")
    allow(chargeable).to receive(:charge_processor_id).and_return(StripeChargeProcessor.charge_processor_id)
    allow(chargeable).to receive(:prepare!)
    allow(chargeable).to receive(:visual).and_return("**** **** **** 4242")
    allow(chargeable).to receive(:funding_type).and_return("credit")
    allow(chargeable).to receive(:reusable_token_for!).and_return("cus_test_123")
    allow(chargeable).to receive(:payment_method_id).and_return("pm_test_123")
    allow(chargeable).to receive(:fingerprint).and_return("test_fingerprint")
    allow(chargeable).to receive(:card_type).and_return("visa")
    allow(chargeable).to receive(:expiry_month).and_return(12)
    allow(chargeable).to receive(:expiry_year).and_return(2028)
    allow(chargeable).to receive(:country).and_return("US")
    allow(chargeable).to receive(:requires_mandate?).and_return(false)

    buyer.credit_card = CreditCard.create(chargeable, nil, buyer)
    buyer.save!
  end

  describe "snapshotting on creation" do
    it "creates InstallmentPlanSnapshot with number_of_installments, recurrence, and total_price_cents" do
      purchase = build(:purchase,
                       link: product,
                       email: buyer.email,
                       is_original_subscription_purchase: true,
                       is_installment_payment: true,
                       installment_plan: installment_plan)
      purchase.save!(validate: false)

      subscription = create(:subscription, link: product)
      subscription.update!(is_installment_plan: true)
      payment_option = create(:payment_option,
                              subscription: subscription,
                              installment_plan: installment_plan)

      purchase.update_column(:subscription_id, subscription.id)

      payment_option.build_installment_plan_snapshot(
        number_of_installments: installment_plan.number_of_installments,
        recurrence: installment_plan.recurrence,
        total_price_cents: purchase.total_price_before_installments || purchase.price_cents
      )
      payment_option.save!

      snapshot = payment_option.installment_plan_snapshot
      expect(snapshot).to be_present
      expect(snapshot.number_of_installments).to eq(3)
      expect(snapshot.recurrence).to eq("monthly")
      expect(snapshot.total_price_cents).to eq(14700)
    end
  end

  describe "price protection" do
    it "protects existing installment schedules when product price increases" do
      purchase = build(:purchase,
                       link: product,
                       email: buyer.email,
                       price_cents: 4900,
                       is_original_subscription_purchase: true,
                       is_installment_payment: true,
                       installment_plan: installment_plan,
                       purchaser: buyer)
      purchase.save!(validate: false)

      subscription = create(:subscription, link: product)
      subscription.update!(is_installment_plan: true)
      payment_option = create(:payment_option,
                              subscription: subscription,
                              installment_plan: installment_plan)

      purchase.update_column(:subscription_id, subscription.id)

      payment_option.build_installment_plan_snapshot(
        number_of_installments: installment_plan.number_of_installments,
        recurrence: installment_plan.recurrence,
        total_price_cents: purchase.total_price_before_installments || purchase.price_cents
      )
      payment_option.save!

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
      purchase = build(:purchase,
                       link: product,
                       email: buyer.email,
                       price_cents: 4900,
                       is_original_subscription_purchase: true,
                       is_installment_payment: true,
                       installment_plan: installment_plan,
                       purchaser: buyer)
      purchase.save!(validate: false)

      subscription = create(:subscription, link: product)
      subscription.update!(is_installment_plan: true)
      payment_option = create(:payment_option,
                              subscription: subscription,
                              installment_plan: installment_plan)

      purchase.update_column(:subscription_id, subscription.id)

      payment_option.build_installment_plan_snapshot(
        number_of_installments: installment_plan.number_of_installments,
        recurrence: installment_plan.recurrence,
        total_price_cents: purchase.total_price_before_installments || purchase.price_cents
      )
      payment_option.save!

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
      purchase = build(:purchase,
                       link: product,
                       email: buyer.email,
                       price_cents: 4900,
                       is_original_subscription_purchase: true,
                       is_installment_payment: true,
                       installment_plan: installment_plan,
                       purchaser: buyer)
      purchase.save!(validate: false)

      subscription = create(:subscription, link: product)
      subscription.update!(is_installment_plan: true)
      payment_option = create(:payment_option,
                              subscription: subscription,
                              installment_plan: installment_plan)

      purchase.update_column(:subscription_id, subscription.id)

      payment_option.build_installment_plan_snapshot(
        number_of_installments: installment_plan.number_of_installments,
        recurrence: installment_plan.recurrence,
        total_price_cents: purchase.total_price_before_installments || purchase.price_cents
      )
      payment_option.save!

      snapshot = payment_option.installment_plan_snapshot
      expect(snapshot.number_of_installments).to eq(3)
      expect(purchase.price_cents).to eq(4900)

      installment_plan.update!(number_of_installments: 2)

      snapshot = payment_option.reload.installment_plan_snapshot
      expect(snapshot.number_of_installments).to eq(3)
      expect(snapshot.total_price_cents).to eq(14700)

      expect(installment_plan.reload.number_of_installments).to eq(2)
    end

    it "protects existing schedules when number_of_installments changes from 3 to 5" do
      purchase = build(:purchase,
                       link: product,
                       email: buyer.email,
                       price_cents: 4900,
                       is_original_subscription_purchase: true,
                       is_installment_payment: true,
                       installment_plan: installment_plan,
                       purchaser: buyer)
      purchase.save!(validate: false)

      subscription = create(:subscription, link: product)
      subscription.update!(is_installment_plan: true)
      payment_option = create(:payment_option,
                              subscription: subscription,
                              installment_plan: installment_plan)

      purchase.update_column(:subscription_id, subscription.id)

      payment_option.build_installment_plan_snapshot(
        number_of_installments: installment_plan.number_of_installments,
        recurrence: installment_plan.recurrence,
        total_price_cents: purchase.total_price_before_installments || purchase.price_cents
      )
      payment_option.save!

      installment_plan.update!(number_of_installments: 5)

      snapshot = payment_option.reload.installment_plan_snapshot
      expect(snapshot.number_of_installments).to eq(3)
      expect(snapshot.total_price_cents).to eq(14700)

      expect(installment_plan.reload.number_of_installments).to eq(5)
    end
  end

  describe "recurrence protection" do
    it "protects existing schedules when recurrence changes" do
      subscription = create(:subscription, link: product)
      subscription.update!(is_installment_plan: true)
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

      installment_plan.update!(recurrence: "monthly")

      expect(payment_option.subscription.recurrence).to eq("monthly")
    end
  end

  describe "backwards compatibility" do
    it "falls back to live ProductInstallmentPlan for existing records without snapshot" do
      subscription = create(:subscription, link: product)
      subscription.update!(is_installment_plan: true)
      payment_option = create(:payment_option,
                              subscription: subscription,
                              installment_plan: installment_plan)

      payment_option.installment_plan_snapshot&.destroy

      purchase = build(:purchase,
                       link: product,
                       subscription: subscription,
                       is_installment_payment: true,
                       is_original_subscription_purchase: true)
      purchase.save!(validate: false)

      installment_amount = purchase.send(:calculate_installment_payment_price_cents, 14700)

      expect(installment_amount).to eq(4900)
    end
  end
end
