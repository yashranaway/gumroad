# frozen_string_literal: true

module BalanceLoading
  class ChargeService
    class ChargeError < StandardError; end
    class InsufficientAmountError < StandardError; end

    MIN_CHARGE_AMOUNT_CENTS = 100

    def initialize(user)
      @user = user
    end

    def charge(amount_cents, balance_load_credit_card: nil, refund: nil)
      validate_amount!(amount_cents)

      card = balance_load_credit_card || @user.default_balance_load_credit_card
      raise ChargeError, "No payment method available" if card.nil?
      raise ChargeError, "Payment method has expired" if card.expired?

      balance_load = @user.balance_loads.create!(
        balance_load_credit_card: card,
        amount_cents:,
        currency: "USD",
        status: "pending",
        refund:
      )

      BalanceLoading::ProcessChargeJob.perform_async(balance_load.id)

      balance_load
    end

    def process_charge(balance_load)
      return if balance_load.successful? || balance_load.failed?

      begin
        stripe_charge = Stripe::Charge.create(
          amount: balance_load.amount_cents,
          currency: balance_load.currency.downcase,
          customer: @user.stripe_customer_id,
          payment_method: balance_load.balance_load_credit_card.stripe_payment_method_id,
          description: "Balance load for #{@user.email}",
          metadata: {
            user_id: @user.id,
            balance_load_id: balance_load.id,
            refund_id: balance_load.refund_id
          },
          confirm: true,
          off_session: true
        )

        balance_load.mark_successful!(stripe_charge.id)
        create_balance_record(balance_load)

        balance_load
      rescue Stripe::CardError => e
        balance_load.mark_failed!(e.message)
        raise ChargeError, e.message
      rescue Stripe::StripeError => e
        balance_load.mark_failed!(e.message)
        raise ChargeError, "Stripe error: #{e.message}"
      end
    end

    private
      def validate_amount!(amount_cents)
        if amount_cents < MIN_CHARGE_AMOUNT_CENTS
          raise InsufficientAmountError, "Minimum charge amount is #{MIN_CHARGE_AMOUNT_CENTS} cents"
        end
      end

      def create_balance_record(balance_load)
        Balance.create!(
          user: @user,
          merchant_account: @user.merchant_accounts.first,
          amount_cents: balance_load.amount_cents,
          currency: balance_load.currency,
          holding_currency: balance_load.currency,
          description: "Balance loaded via credit card",
          balance_type: "balance_load"
        )
      end
  end
end
