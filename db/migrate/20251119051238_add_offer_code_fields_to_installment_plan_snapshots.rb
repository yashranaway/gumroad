class AddOfferCodeFieldsToInstallmentPlanSnapshots < ActiveRecord::Migration[7.1]
  def change
    add_column :installment_plan_snapshots, :original_offer_code_id, :integer
    add_column :installment_plan_snapshots, :original_offer_code_amount_cents, :integer
    add_column :installment_plan_snapshots, :original_offer_code_amount_percentage, :integer
    add_column :installment_plan_snapshots, :original_offer_code_is_percent, :boolean
    add_column :installment_plan_snapshots, :original_offer_code_duration_in_months, :integer
    add_column :installment_plan_snapshots, :original_offer_code_code, :string
    add_column :installment_plan_snapshots, :original_offer_code_currency, :string

    add_index :installment_plan_snapshots, :original_offer_code_id
  end
end
