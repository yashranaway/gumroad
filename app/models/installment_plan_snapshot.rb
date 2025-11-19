# frozen_string_literal: true

class InstallmentPlanSnapshot < ApplicationRecord
  belongs_to :payment_option
  belongs_to :original_offer_code, class_name: "OfferCode", optional: true

  validates :payment_option, uniqueness: true
  validates :number_of_installments, presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :recurrence, presence: true
  validates :total_price_cents, presence: true, numericality: { greater_than: 0, only_integer: true }

  def calculate_installment_payment_price_cents
    base_price = total_price_cents / number_of_installments
    remainder = total_price_cents % number_of_installments

    Array.new(number_of_installments) do |i|
      i.zero? ? base_price + remainder : base_price
    end
  end

  def has_original_offer_code?
    original_offer_code_id.present?
  end

  def original_offer_code_amount_off(price_cents)
    return 0 if !has_original_offer_code?
    return original_offer_code_amount_cents if !original_offer_code_is_percent?

    (price_cents * (original_offer_code_amount_percentage / 100.0)).round
  end
end
