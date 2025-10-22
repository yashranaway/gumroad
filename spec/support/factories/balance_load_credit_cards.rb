# frozen_string_literal: true

FactoryBot.define do
  factory :balance_load_credit_card do
    user
    stripe_payment_method_id { "pm_#{SecureRandom.hex(12)}" }
    last4 { rand(1000..9999).to_s }
    brand { %w[visa mastercard amex discover].sample }
    exp_month { rand(1..12) }
    exp_year { rand(Time.current.year..(Time.current.year + 5)) }
    is_default { false }

    trait :default do
      is_default { true }
    end

    trait :expired do
      exp_month { 1 }
      exp_year { Time.current.year - 1 }
    end

    trait :expiring_soon do
      exp_month { Time.current.month }
      exp_year { Time.current.year }
    end

    trait :deleted do
      deleted_at { Time.current }
    end
  end
end
