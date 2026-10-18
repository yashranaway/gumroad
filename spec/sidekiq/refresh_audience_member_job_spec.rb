# frozen_string_literal: true

require "spec_helper"

describe RefreshAudienceMemberJob do
  describe ".enqueue" do
    it "schedules the refresh with the email and seller id", :defer_audience_refresh do
      described_class.enqueue("buyer@example.com", 42)

      expect(described_class).to have_enqueued_sidekiq_job("buyer@example.com", 42)
    end

    it "does not raise when Redis cannot accept the enqueue", :defer_audience_refresh do
      # The call sites run in after_commit on a committed follow/purchase: a Redis stall there
      # used to surface as a 500 for a write that had already landed.
      allow(described_class).to receive(:perform_async)
        .and_raise(RedisClient::CannotConnectError, "Waited 3 seconds (redis://production-redis-2)")

      expect { described_class.enqueue("buyer@example.com", 42) }.not_to raise_error
    end
  end
end
