# frozen_string_literal: true

class BalanceLoadCreditCard < ApplicationRecord
  include ExternalId
  include Deletable

  belongs_to :user
  has_many :balance_loads, dependent: :restrict_with_error

  validates :stripe_payment_method_id, presence: true, uniqueness: true
  validates :last4, presence: true, length: { is: 4 }
  validates :brand, presence: true
  validates :exp_month, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
  validates :exp_year, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: Time.current.year }
  validate :only_one_default_per_user, if: :is_default?

  scope :alive, -> { where(deleted_at: nil) }
  scope :default_cards, -> { alive.where(is_default: true) }

  before_save :unset_other_defaults, if: :is_default?

  def expired?
    Date.new(exp_year, exp_month, -1) < Date.current
  end

  def expiring_soon?(months: 1)
    Date.new(exp_year, exp_month, -1) < months.months.from_now
  end

  def display_name
    "#{brand} ****#{last4}"
  end

  private
    def only_one_default_per_user
      if user.balance_load_credit_cards.alive.where(is_default: true).where.not(id:).exists?
        errors.add(:is_default, "can only have one default card")
      end
    end

    def unset_other_defaults
      user.balance_load_credit_cards.alive.where.not(id:).update_all(is_default: false)
    end
end
