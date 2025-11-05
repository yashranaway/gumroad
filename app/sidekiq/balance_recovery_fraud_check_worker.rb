# frozen_string_literal: true

class BalanceRecoveryFraudCheckWorker
  include Sidekiq::Job
  sidekiq_options retry: 2, queue: :default

  def perform(user_id)
    user = User.find(user_id)
    user.check_for_balance_recovery_and_mark_compliant
  end
end
