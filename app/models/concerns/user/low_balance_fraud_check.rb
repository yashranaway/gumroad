# frozen_string_literal: true

module User::LowBalanceFraudCheck
  extend ActiveSupport::Concern

  LOW_BALANCE_THRESHOLD = -100_00 # USD -100
  private_constant :LOW_BALANCE_THRESHOLD

  LOW_BALANCE_PROBATION_WAIT_TIME = 2.months
  private_constant :LOW_BALANCE_PROBATION_WAIT_TIME

  LOW_BALANCE_FRAUD_CHECK_AUTHOR_NAME = "LowBalanceFraudCheck"
  private_constant :LOW_BALANCE_FRAUD_CHECK_AUTHOR_NAME

  BALANCE_RECOVERY_THRESHOLD = 100_00 # USD $100
  private_constant :BALANCE_RECOVERY_THRESHOLD

  def enable_refunds!
    self.refunds_disabled = false
    save!
  end

  def disable_refunds!
    self.refunds_disabled = true
    save!
  end

  def check_for_low_balance_and_probate(refunded_or_disputed_purchase_id)
    return if unpaid_balance_cents > LOW_BALANCE_THRESHOLD

    AdminMailer.low_balance_notify(id, refunded_or_disputed_purchase_id).deliver_later
    disable_refunds_and_put_on_probation! unless recently_probated_for_low_balance?
  end

  def check_for_balance_recovery_and_mark_compliant
    return unless on_probation?
    return unless probated_by_low_balance_fraud_check?
    return if unpaid_balance_cents <= BALANCE_RECOVERY_THRESHOLD

    probation_comment = comments.with_type_on_probation
                               .where(author_name: LOW_BALANCE_FRAUD_CHECK_AUTHOR_NAME)
                               .order(created_at: :desc)
                               .first

    previous_state = probation_comment&.json_data&.dig("previous_risk_state") || "compliant"

    content = "Automatically restored to #{previous_state} state on #{Time.current.to_fs(:formatted_date_full_month)} as balance recovered above $100"

    case previous_state
    when "not_reviewed"
      mark_not_reviewed!(author_name: LOW_BALANCE_FRAUD_CHECK_AUTHOR_NAME, content: content)
    when "compliant"
      mark_compliant!(author_name: LOW_BALANCE_FRAUD_CHECK_AUTHOR_NAME, content: content)
    else
      mark_compliant!(author_name: LOW_BALANCE_FRAUD_CHECK_AUTHOR_NAME, content: content)
    end
  end

  private
    def probated_by_low_balance_fraud_check?
      comments.with_type_on_probation
              .where(author_name: LOW_BALANCE_FRAUD_CHECK_AUTHOR_NAME)
              .exists?
    end

    def disable_refunds_and_put_on_probation!
      disable_refunds!

      previous_state = user_risk_state
      content = "Probated (payouts suspended) automatically on #{Time.current.to_fs(:formatted_date_full_month)} because of suspicious refund activity"

      comments.create!(
        content:,
        comment_type: Comment::COMMENT_TYPE_ON_PROBATION,
        author_name: LOW_BALANCE_FRAUD_CHECK_AUTHOR_NAME,
        json_data: { previous_risk_state: previous_state }
      )

      self.put_on_probation(author_name: LOW_BALANCE_FRAUD_CHECK_AUTHOR_NAME, content: content)
    end

    def recently_probated_for_low_balance?
      comments.with_type_on_probation
              .where(author_name: LOW_BALANCE_FRAUD_CHECK_AUTHOR_NAME)
              .where("created_at > ?", LOW_BALANCE_PROBATION_WAIT_TIME.ago)
              .exists?
    end
end
