class CreateBalanceLoads < ActiveRecord::Migration[7.1]
  def change
    create_table :balance_loads do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.references :balance_load_credit_card, null: false, foreign_key: true, index: true
      t.bigint :amount_cents, null: false
      t.string :currency, null: false, limit: 3, default: "USD"
      t.string :stripe_charge_id, limit: 191
      t.string :status, null: false, limit: 50, default: "pending"
      t.references :refund, foreign_key: true, index: true
      t.string :external_id, null: false, limit: 191
      t.text :error_message

      t.timestamps
    end

    add_index :balance_loads, :external_id, unique: true
    add_index :balance_loads, :stripe_charge_id, unique: true
    add_index :balance_loads, :status
    add_index :balance_loads, [:user_id, :created_at]
  end
end
