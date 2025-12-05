# frozen_string_literal: true

class InstallmentPlanSnapshot < ApplicationRecord
  belongs_to :payment_option

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
    original_offer_code_id.present? && (original_offer_code_amount_cents.present? || original_offer_code_amount_percentage.present?)
  end

  def original_offer_code_amount_off(price_cents)
    return 0 if !has_original_offer_code?
    return original_offer_code_amount_cents if !original_offer_code_is_percent?

    (price_cents * (original_offer_code_amount_percentage / 100.0)).round
  end

  def original_offer_code_display_code
    original_offer_code_code
  end

  def displayed_amount_off(currency_type, with_symbol: false)
    return nil unless has_original_offer_code?

    if with_symbol
      if original_offer_code_is_percent?
        "#{original_offer_code_amount_percentage}%"
      else
        Money.new(original_offer_code_amount_cents, currency_type).format(no_cents_if_whole: true, symbol: true)
      end
    else
      if original_offer_code_is_percent?
        original_offer_code_amount_percentage
      else
        Money.new(original_offer_code_amount_cents, currency_type).format(no_cents_if_whole: true, symbol: false)
      end
    end
  end
end
