# frozen_string_literal: true

class BalanceLoad < ApplicationRecord
  has_paper_trail
  include ExternalId

  STATUSES = %w[pending successful failed].freeze

  belongs_to :user
  belongs_to :balance_load_credit_card
  belongs_to :refund, optional: true

  validates :amount_cents, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, presence: true, inclusion: { in: %w[USD] }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :stripe_charge_id, uniqueness: true, allow_nil: true

  scope :pending, -> { where(status: "pending") }
  scope :successful, -> { where(status: "successful") }
  scope :failed, -> { where(status: "failed") }
  scope :recent, -> { order(created_at: :desc) }

  def mark_successful!(stripe_charge_id)
    update!(
      status: "successful",
      stripe_charge_id:,
      error_message: nil
    )
  end

  def mark_failed!(error_message)
    update!(
      status: "failed",
      error_message:
    )
  end

  def pending?
    status == "pending"
  end

  def successful?
    status == "successful"
  end

  def failed?
    status == "failed"
  end

  def amount_dollars
    amount_cents / 100.0
  end
end
