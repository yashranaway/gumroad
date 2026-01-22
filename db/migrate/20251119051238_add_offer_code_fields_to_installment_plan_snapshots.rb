# frozen_string_literal: true

class AddOfferCodeFieldsToInstallmentPlanSnapshots < ActiveRecord::Migration[7.1]
  def change
    change_table :installment_plan_snapshots, bulk: true do |t|
      t.integer :original_offer_code_id
      t.integer :original_offer_code_amount_cents
      t.integer :original_offer_code_amount_percentage
      t.boolean :original_offer_code_is_percent
      t.integer :original_offer_code_duration_in_months
      t.string :original_offer_code_code
      t.string :original_offer_code_currency
      t.index :original_offer_code_id
    end
  end
end
