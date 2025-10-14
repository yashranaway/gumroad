# frozen_string_literal: true

module Onetime
  class BackfillPaymentOptionInstallmentSnapshots
    def self.perform
      PaymentOption.where.not(product_installment_plan_id: nil)
                   .where(snapshot_number_of_installments: nil)
                   .find_in_batches(batch_size: 1000) do |batch|
        batch.each do |payment_option|
          next unless payment_option.installment_plan.present?
          next unless payment_option.subscription&.original_purchase.present?

          payment_option.update_columns(
            snapshot_number_of_installments: payment_option.installment_plan.number_of_installments,
            snapshot_recurrence: payment_option.installment_plan.recurrence,
            snapshot_total_price_cents: payment_option.subscription.original_purchase.minimum_paid_price_cents
          )
        rescue StandardError => e
          Rails.logger.error("Failed to backfill PaymentOption #{payment_option.id}: #{e.message}")
        end

        puts "Backfilled #{batch.size} payment options"
      end
    end
  end
end
