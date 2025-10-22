# frozen_string_literal: true

FactoryBot.define do
  factory :balance_load do
    user
    balance_load_credit_card
    amount_cents { rand(100..10000) }
    currency { "USD" }
    status { "pending" }

    trait :pending do
      status { "pending" }
    end

    trait :successful do
      status { "successful" }
      stripe_charge_id { "ch_#{SecureRandom.hex(12)}" }
    end

    trait :failed do
      status { "failed" }
      error_message { "Card was declined" }
    end

    trait :with_refund do
      refund
    end
  end
end
