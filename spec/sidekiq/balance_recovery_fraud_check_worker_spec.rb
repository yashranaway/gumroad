# frozen_string_literal: true

require "spec_helper"

describe BalanceRecoveryFraudCheckWorker do
  let(:creator) { create(:user) }

  describe "#perform" do
    it "calls check_for_balance_recovery_and_mark_compliant on the user" do
      expect_any_instance_of(User).to receive(:check_for_balance_recovery_and_mark_compliant)

      described_class.new.perform(creator.id)
    end
  end
end
