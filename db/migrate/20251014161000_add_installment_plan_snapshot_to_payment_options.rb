# frozen_string_literal: true

class AddInstallmentPlanSnapshotToPaymentOptions < ActiveRecord::Migration[7.1]
  def change
    change_table :payment_options, bulk: true do |t|
      t.integer :snapshot_number_of_installments
      t.string :snapshot_recurrence
      t.integer :snapshot_total_price_cents
    end
  end
end
