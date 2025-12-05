# frozen_string_literal: true

class BackfillOfferCodeFieldsToInstallmentPlanSnapshots < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      UPDATE installment_plan_snapshots
      JOIN offer_codes ON installment_plan_snapshots.original_offer_code_id = offer_codes.id
      SET installment_plan_snapshots.original_offer_code_code = offer_codes.code,
          installment_plan_snapshots.original_offer_code_currency = offer_codes.currency_type,
          installment_plan_snapshots.original_offer_code_duration_in_months = offer_codes.duration_in_months
      WHERE installment_plan_snapshots.original_offer_code_id IS NOT NULL
        AND installment_plan_snapshots.original_offer_code_code IS NULL
    SQL

    execute <<-SQL.squish
      UPDATE installment_plan_snapshots
      JOIN payment_options ON installment_plan_snapshots.payment_option_id = payment_options.id
      JOIN subscriptions ON payment_options.subscription_id = subscriptions.id
      JOIN purchases ON purchases.subscription_id = subscriptions.id
        AND (purchases.flags & 4) = 4
      JOIN offer_codes ON purchases.offer_code_id = offer_codes.id
      SET installment_plan_snapshots.original_offer_code_id = offer_codes.id,
          installment_plan_snapshots.original_offer_code_amount_cents = offer_codes.amount_cents,
          installment_plan_snapshots.original_offer_code_amount_percentage = offer_codes.amount_percentage,
          installment_plan_snapshots.original_offer_code_is_percent = CASE WHEN offer_codes.amount_percentage IS NOT NULL THEN 1 ELSE 0 END,
          installment_plan_snapshots.original_offer_code_duration_in_months = offer_codes.duration_in_months,
          installment_plan_snapshots.original_offer_code_code = offer_codes.code,
          installment_plan_snapshots.original_offer_code_currency = offer_codes.currency_type
      WHERE (subscriptions.flags & 64) = 64
        AND purchases.offer_code_id IS NOT NULL
        AND installment_plan_snapshots.original_offer_code_id IS NULL
    SQL
  end

  def down
  end
end
