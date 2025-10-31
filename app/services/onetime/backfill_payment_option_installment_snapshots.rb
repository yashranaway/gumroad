# frozen_string_literal: true

module Onetime
  class BackfillPaymentOptionInstallmentSnapshots
    def self.perform
      PaymentOption.where.not(product_installment_plan_id: nil)
                   .where.missing(:installment_plan_snapshot)
                   .find_each do |payment_option|
        next unless payment_option.installment_plan.present?
        next unless payment_option.subscription&.original_purchase.present?

        subscription = payment_option.subscription
        installment_plan = payment_option.installment_plan
        
        total_price = calculate_total_price_from_history(subscription, installment_plan)

        InstallmentPlanSnapshot.create!(
          payment_option: payment_option,
          number_of_installments: installment_plan.number_of_installments,
          recurrence: installment_plan.recurrence,
          total_price_cents: total_price
        )
      rescue StandardError => e
        Rails.logger.error("Failed to backfill PaymentOption #{payment_option.id}: #{e.message}")
      end
    end

    def self.calculate_total_price_from_history(subscription, installment_plan)
      original_purchase = subscription.original_purchase
      
      all_installment_purchases = subscription.purchases
        .successful
        .is_installment_payment
        .order(:created_at)
      
      if all_installment_purchases.count > 1
        total_paid = all_installment_purchases.sum(:price_cents)
        completed_installments = all_installment_purchases.count
        expected_installments = installment_plan.number_of_installments
        
        if completed_installments >= expected_installments
          return total_paid
        else
          average_per_installment = total_paid / completed_installments
          return (average_per_installment * expected_installments).round
        end
      end

      if original_purchase.total_price_before_installments.present?
        return original_purchase.total_price_before_installments
      end

      original_purchase.price_cents
    end
  end
end
