# frozen_string_literal: true

# Usage:
# Onetime::NotifySellersMissingPaypalDisputePermissions.new.process_with_logging
class Onetime::NotifySellersMissingPaypalDisputePermissions < Onetime::Base
  def process
    merchant_accounts = MerchantAccount.alive
      .where(charge_processor_id: PaypalChargeProcessor.charge_processor_id)
      .where.not(charge_processor_verified_at: nil)

    notified = 0
    skipped = 0
    api_failures = 0
    errored = 0

    merchant_accounts.find_each do |merchant_account|
      ReplicaLagWatcher.watch

      user = merchant_account.user
      next if user.blank?

      api = PaypalIntegrationRestApi.new(user, authorization_header: PaypalPartnerRestCredentials.new.auth_token)
      response = api.get_merchant_account_by_merchant_id(merchant_account.charge_processor_merchant_id)

      if !response.success?
        api_failures += 1
        Rails.logger.warn "API failure for merchant_account #{merchant_account.id}: HTTP #{response.code}"
      elsif !PaypalMerchantAccountManager.paypal_disputes_scopes_granted?(response.parsed_response)
        MerchantRegistrationMailer.paypal_dispute_permissions_needed(user.id).deliver_later(queue: "low")
        notified += 1
        Rails.logger.info "Notified seller #{user.id} (merchant_account #{merchant_account.id})"
      else
        skipped += 1
      end
    rescue => e
      errored += 1
      Rails.logger.error "Error checking merchant_account #{merchant_account.id}: #{e.class}: #{e.message}"
    end

    Rails.logger.info "Done. Notified: #{notified}, Skipped: #{skipped}, API failures: #{api_failures}, Errors: #{errored}"
  end
end
