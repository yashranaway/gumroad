# frozen_string_literal: true

module Refund::BalanceLoadIntegration
  extend ActiveSupport::Concern

  def check_and_load_balance_if_needed(refund_amount_cents)
    return true if balance_load_disabled?

    seller_balance = seller.balances.sum(:amount_cents)

    if seller_balance < refund_amount_cents
      load_balance_for_refund(refund_amount_cents - seller_balance)
    else
      true
    end
  end

  private
    def balance_load_disabled?
      !Flipper.enabled?(:balance_load_for_refunds, seller)
    end

    def load_balance_for_refund(amount_needed)
      charge_service = BalanceLoading::ChargeService.new(seller)

      begin
        charge_service.charge(amount_needed, refund: self)
        true
      rescue BalanceLoading::ChargeService::ChargeError => e
        errors.add(:base, "Unable to load balance: #{e.message}")
        false
      rescue BalanceLoading::ChargeService::InsufficientAmountError => e
        errors.add(:base, e.message)
        false
      end
    end
end
