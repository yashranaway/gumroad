# frozen_string_literal: true

class PaymentOption < ApplicationRecord
  include Deletable

  belongs_to :subscription
  belongs_to :price
  belongs_to :installment_plan,
             foreign_key: :product_installment_plan_id, class_name: "ProductInstallmentPlan",
             optional: true

  validates :installment_plan, presence: true, if: -> { subscription&.is_installment_plan }

  after_create :update_subscription_last_payment_option
  after_update :update_subscription_last_payment_option, if: :saved_change_to_deleted_at?
  after_destroy :update_subscription_last_payment_option

  def offer_code
    subscription.original_purchase.offer_code
  end

  def variant_attributes
    subscription.original_purchase.variant_attributes
  end

  def update_subscription_last_payment_option
    subscription.update_last_payment_option
  end

  def calculate_installment_payment_price_cents(total_price_cents)
    return unless has_installment_plan_snapshot?

    base_price = total_price_cents / snapshot_number_of_installments
    remainder = total_price_cents % snapshot_number_of_installments

    Array.new(snapshot_number_of_installments) do |i|
      i.zero? ? base_price + remainder : base_price
    end
  end

  def has_installment_plan_snapshot?
    snapshot_number_of_installments.present? && snapshot_total_price_cents.present?
  end
end
