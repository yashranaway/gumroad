# frozen_string_literal: true

class AddRefundFundingToCredits < ActiveRecord::Migration[7.1]
  def change
    change_table :credits, bulk: true do |t|
      t.bigint :refund_funding_purchase_id
      t.bigint :credit_card_id
      t.index :refund_funding_purchase_id
      t.index :credit_card_id
    end
  end
end
