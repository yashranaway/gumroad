# frozen_string_literal: true

class PaymentOption < ApplicationRecord
  include Deletable

  belongs_to :subscription
  belongs_to :price
  belongs_to :installment_plan,
             foreign_key: :product_installment_plan_id, class_name: "ProductInstallmentPlan",
             optional: true
  has_one :installment_plan_snapshot, dependent: :destroy

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

  def snapshot_installment_plan!(purchase)
    return unless installment_plan.present?

    InstallmentPlanSnapshot.create!(
      payment_option: self,
      number_of_installments: installment_plan.number_of_installments,
      recurrence: installment_plan.recurrence,
      total_price_cents: purchase.minimum_paid_price_cents
    )
  end
end
