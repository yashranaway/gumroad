# frozen_string_literal: true

module User::LowBalanceFraudCheck
  extend ActiveSupport::Concern

  LOW_BALANCE_THRESHOLD_IN_CENTS = -100_00 # USD -100
  private_constant :LOW_BALANCE_THRESHOLD_IN_CENTS

  LOW_BALANCE_PROBATION_WAIT_TIME = 2.months
  private_constant :LOW_BALANCE_PROBATION_WAIT_TIME

  LOW_BALANCE_FRAUD_CHECK_AUTHOR_NAME = "LowBalanceFraudCheck"
  private_constant :LOW_BALANCE_FRAUD_CHECK_AUTHOR_NAME

  BALANCE_RECOVERY_THRESHOLD_IN_CENTS = 100_00 # USD $100
  private_constant :BALANCE_RECOVERY_THRESHOLD_IN_CENTS

  def enable_refunds!
    self.refunds_disabled = false
    save!
  end

  def disable_refunds!
    self.refunds_disabled = true
    save!
  end

  def check_for_low_balance_and_probate(refunded_or_disputed_purchase_id)
    return if unpaid_balance_cents > LOW_BALANCE_THRESHOLD_IN_CENTS

    AdminMailer.low_balance_notify(id, refunded_or_disputed_purchase_id).deliver_later
    disable_refunds_and_put_on_probation! unless recently_probated_for_low_balance?
  end

  def check_for_balance_recovery_and_mark_compliant
    return unless on_probation?
    return unless probated_by_low_balance_fraud_check?
    return if unpaid_balance_cents.nil? || unpaid_balance_cents <= BALANCE_RECOVERY_THRESHOLD_IN_CENTS

    previous_state = get_previous_risk_state_before_probation
    return if previous_state.nil?

    content = "Automatically restored to #{previous_state} state on #{Time.current.to_fs(:formatted_date_full_month)} as balance recovered above $100"

    restore_to_previous_state!(previous_state, author_name: LOW_BALANCE_FRAUD_CHECK_AUTHOR_NAME, content: content)
  end

  private
    def get_previous_risk_state_before_probation
      probation_version = versions.reorder(created_at: :desc).find do |version|
        next if version.object_changes.blank?
        changes = PaperTrail.serializer.load(version.object_changes)
        changes["user_risk_state"]&.last == "on_probation"
      end

      return nil unless probation_version

      changes = PaperTrail.serializer.load(probation_version.object_changes)
      changes["user_risk_state"]&.first
    end

    def restore_to_previous_state!(state, author_name:, content:)
      case state
      when "not_reviewed"
        mark_not_reviewed!(author_name: author_name, content: content)
        enable_refunds!
      when "compliant"
        mark_compliant!(author_name: author_name, content: content)
      when "flagged_for_fraud", "flagged_for_tos_violation"
        mark_compliant!(author_name: author_name, content: content)
      else
        mark_compliant!(author_name: author_name, content: content)
      end
    end

    def probated_by_low_balance_fraud_check?
      most_recent_probation_comment = comments.with_type_on_probation.order(created_at: :desc).first
      return false unless most_recent_probation_comment

      most_recent_probation_comment.author_name == LOW_BALANCE_FRAUD_CHECK_AUTHOR_NAME
    end

    def disable_refunds_and_put_on_probation!
      transaction do
        disable_refunds!
        put_on_probation(author_name: LOW_BALANCE_FRAUD_CHECK_AUTHOR_NAME)
      end
    end

    def recently_probated_for_low_balance?
      comments.with_type_on_probation
              .where(author_name: LOW_BALANCE_FRAUD_CHECK_AUTHOR_NAME)
              .where("created_at > ?", LOW_BALANCE_PROBATION_WAIT_TIME.ago)
              .exists?
    end
end
