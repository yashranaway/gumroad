# frozen_string_literal: true

FactoryBot.define do
  factory :subscription do
    association :link, factory: :product
    user

    transient do
      price { nil }
      purchase_email { nil }
    end

    before(:create) do |subscription, evaluator|
      if subscription.is_installment_plan
        installment_plan = subscription.link.installment_plan
        if installment_plan.present?
          payment_option = create(
            :payment_option,
            subscription:,
            price: evaluator.price || subscription.link.default_price,
            installment_plan: installment_plan
          )
          subscription.payment_options << payment_option
          subscription.charge_occurrence_count = installment_plan.number_of_installments
        end
      else
        payment_option = create(
          :payment_option,
          subscription:,
          price: evaluator.price || subscription.link.default_price,
          installment_plan: nil
        )
        subscription.payment_options << payment_option
      end
    end

    factory :subscription_without_user do
      user { nil }

      transient do
        email { generate :email }
      end

      before(:create) do |subscription, evaluator|
        purchase = create(:purchase, link: subscription.link, is_original_subscription_purchase: true, email: evaluator.email)
        subscription.purchases << purchase
      end
    end
  end
end
