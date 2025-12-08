# frozen_string_literal: true

module Onetime
  class BackfillOfferCodeFieldsToInstallmentSnapshots
    def self.perform
      InstallmentPlanSnapshot.where.not(original_offer_code_id: nil)
                             .where(original_offer_code_code: nil)
                             .find_each do |snapshot|
        offer_code = OfferCode.find_by(id: snapshot.original_offer_code_id)
        next unless offer_code

        snapshot.update!(
          original_offer_code_code: offer_code.code,
          original_offer_code_currency: offer_code.currency_type,
          original_offer_code_duration_in_months: offer_code.duration_in_months
        )
      rescue StandardError => e
        Rails.logger.error("Failed to backfill snapshot #{snapshot.id}: #{e.message}")
      end

      backfill_snapshots_from_purchases
    end

    def self.backfill_snapshots_from_purchases
      InstallmentPlanSnapshot.where(original_offer_code_id: nil)
                             .includes(payment_option: { subscription: :original_purchase })
                             .find_each do |snapshot|
        subscription = snapshot.payment_option&.subscription
        next unless subscription&.is_installment_plan?

        original_purchase = subscription.original_purchase
        next unless original_purchase&.offer_code.present?

        offer_code = original_purchase.offer_code
        snapshot.update!(
          original_offer_code_id: offer_code.id,
          original_offer_code_amount_cents: offer_code.amount_cents,
          original_offer_code_amount_percentage: offer_code.amount_percentage,
          original_offer_code_is_percent: offer_code.is_percent?,
          original_offer_code_duration_in_months: offer_code.duration_in_months,
          original_offer_code_code: offer_code.code,
          original_offer_code_currency: offer_code.currency_type
        )
      rescue StandardError => e
        Rails.logger.error("Failed to backfill snapshot #{snapshot.id} from purchase: #{e.message}")
      end
    end
  end
end
