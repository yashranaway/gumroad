# frozen_string_literal: true

module BalanceLoading
  class ProcessChargeJob
    include Sidekiq::Job

    sidekiq_options queue: :default, retry: 3, lock: :until_executed

    def perform(balance_load_id)
      balance_load = ::BalanceLoad.find(balance_load_id)
      user = balance_load.user

      charge_service = BalanceLoading::ChargeService.new(user)
      charge_service.process_charge(balance_load)
    rescue BalanceLoading::ChargeService::ChargeError => e
      Bugsnag.notify(e) do |report|
        report.add_metadata(:balance_load, {
                              id: balance_load_id,
                              user_id: balance_load&.user_id,
                              amount_cents: balance_load&.amount_cents
                            })
      end
      raise
    end
  end
end
