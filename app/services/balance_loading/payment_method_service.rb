# frozen_string_literal: true

module BalanceLoading
  class PaymentMethodService
    class AttachmentError < StandardError; end
    class DetachmentError < StandardError; end

    def initialize(user)
      @user = user
    end

    def attach_payment_method(stripe_payment_method_id, set_as_default: false)
      payment_method = Stripe::PaymentMethod.retrieve(stripe_payment_method_id)

      if payment_method.customer && payment_method.customer != @user.stripe_customer_id
        raise AttachmentError, "Payment method belongs to another customer"
      end

      if payment_method.customer.nil?
        Stripe::PaymentMethod.attach(
          stripe_payment_method_id,
          { customer: @user.stripe_customer_id }
        )
      end

      card = payment_method.card
      balance_load_credit_card = @user.balance_load_credit_cards.create!(
        stripe_payment_method_id:,
        last4: card.last4,
        brand: card.brand,
        exp_month: card.exp_month,
        exp_year: card.exp_year,
        is_default: set_as_default || @user.alive_balance_load_credit_cards.empty?
      )

      balance_load_credit_card
    rescue Stripe::StripeError => e
      raise AttachmentError, "Stripe error: #{e.message}"
    end

    def detach_payment_method(balance_load_credit_card)
      if balance_load_credit_card.balance_loads.exists?
        balance_load_credit_card.mark_deleted!
      else
        Stripe::PaymentMethod.detach(balance_load_credit_card.stripe_payment_method_id)
        balance_load_credit_card.destroy!
      end
    rescue Stripe::StripeError => e
      raise DetachmentError, "Stripe error: #{e.message}"
    end

    def set_default_payment_method(balance_load_credit_card)
      balance_load_credit_card.update!(is_default: true)
    end
  end
end
