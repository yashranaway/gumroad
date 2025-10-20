# frozen_string_literal: true

require "spec_helper"

describe "Product installment plan price and configuration protection", type: :system, js: true do
  let!(:seller) { create(:user, tipping_enabled: true) }
  let!(:product) { create(:product, name: "Course", user: seller, price_cents: 14700) }
  let!(:installment_plan) { create(:product_installment_plan, link: product, number_of_installments: 3) }

  describe "price change protection" do
    it "locks installment amounts when product price increases after purchase" do
      visit product.long_url
      expect(page).to have_text("First installment of $49, followed by 2 monthly installments of $49", normalize_ws: true)

      click_on "Pay in 3 installments"
      fill_checkout_form(product)
      click_on "Pay"

      expect(page).to have_alert(text: "Your purchase was successful! We sent a receipt to test@gumroad.com.")

      purchase = product.sales.last
      subscription = purchase.subscription
      snapshot = subscription.last_payment_option.installment_plan_snapshot

      expect(purchase.price_cents).to eq(4900)
      expect(snapshot.total_price_cents).to eq(14700)
      expect(snapshot.number_of_installments).to eq(3)

      product.update!(price_cents: 19700)

      travel_to(1.month.from_now)
      RecurringChargeWorker.new.perform(subscription.id)

      second_purchase = subscription.purchases.successful.last
      expect(second_purchase.price_cents).to eq(4900)

      travel_to(2.months.from_now)
      RecurringChargeWorker.new.perform(subscription.id)

      third_purchase = subscription.purchases.successful.last
      expect(third_purchase.price_cents).to eq(4900)

      expect(subscription.purchases.successful.sum(:price_cents)).to eq(14700)
    end

    it "locks installment amounts when product price decreases after purchase" do
      visit product.long_url
      click_on "Pay in 3 installments"
      fill_checkout_form(product)
      click_on "Pay"

      expect(page).to have_alert(text: "Your purchase was successful! We sent a receipt to test@gumroad.com.")

      purchase = product.sales.last
      subscription = purchase.subscription

      expect(purchase.price_cents).to eq(4900)

      product.update!(price_cents: 10000)

      travel_to(1.month.from_now)
      RecurringChargeWorker.new.perform(subscription.id)

      second_purchase = subscription.purchases.successful.last
      expect(second_purchase.price_cents).to eq(4900)

      expect(subscription.purchases.successful.sum(:price_cents)).to eq(9800)
    end
  end

  describe "installment configuration change protection" do
    it "locks the number of installments when changed from 3 to 2 after purchase" do
      visit product.long_url
      click_on "Pay in 3 installments"
      fill_checkout_form(product)
      click_on "Pay"

      purchase = product.sales.last
      subscription = purchase.subscription

      installment_plan.update!(number_of_installments: 2)

      travel_to(1.month.from_now)
      RecurringChargeWorker.new.perform(subscription.id)

      expect(subscription.purchases.successful.count).to eq(2)

      travel_to(2.months.from_now)
      RecurringChargeWorker.new.perform(subscription.id)

      expect(subscription.purchases.successful.count).to eq(3)
      expect(subscription.charges_completed?).to be(true)
    end

    it "locks the number of installments when changed from 3 to 5 after purchase" do
      visit product.long_url
      click_on "Pay in 3 installments"
      fill_checkout_form(product)
      click_on "Pay"

      purchase = product.sales.last
      subscription = purchase.subscription

      installment_plan.update!(number_of_installments: 5)

      travel_to(1.month.from_now)
      RecurringChargeWorker.new.perform(subscription.id)

      travel_to(2.months.from_now)
      RecurringChargeWorker.new.perform(subscription.id)

      expect(subscription.purchases.successful.count).to eq(3)
      expect(subscription.charges_completed?).to be(true)
    end
  end
end
