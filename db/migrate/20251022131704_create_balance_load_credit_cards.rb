class CreateBalanceLoadCreditCards < ActiveRecord::Migration[7.1]
  def change
    create_table :balance_load_credit_cards do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string :stripe_payment_method_id, null: false, limit: 191
      t.string :last4, null: false, limit: 4
      t.string :brand, null: false, limit: 50
      t.integer :exp_month, null: false
      t.integer :exp_year, null: false
      t.boolean :is_default, default: false, null: false
      t.datetime :deleted_at
      t.string :external_id, null: false, limit: 191

      t.timestamps
    end

    add_index :balance_load_credit_cards, :external_id, unique: true
    add_index :balance_load_credit_cards, :stripe_payment_method_id, unique: true
    add_index :balance_load_credit_cards, :deleted_at
    add_index :balance_load_credit_cards, [:user_id, :is_default], where: "deleted_at IS NULL AND is_default = 1", name: "index_balance_load_credit_cards_on_user_default"
  end
end
