# frozen_string_literal: true

class CreateInstallmentPlanSnapshots < ActiveRecord::Migration[7.1]
  def change
    create_table :installment_plan_snapshots do |t|
      t.references :payment_option, null: false, foreign_key: true, index: { unique: true }
      t.integer :number_of_installments, null: false
      t.string :recurrence, null: false
      t.integer :total_price_cents, null: false
      t.timestamps
    end
  end
end
