# frozen_string_literal: true

require "spec_helper"

describe InstallmentEvent do
  context "Creation" do
    it "queues update of Installment's installment_events_count" do
      installment_event = create(:installment_event)
      expect(UpdateInstallmentEventsCountCacheWorker).to have_enqueued_sidekiq_job(installment_event.installment_id)
    end
  end

  it "keeps the event when the count refresh cannot reach Redis" do
    allow(UpdateInstallmentEventsCountCacheWorker).to receive(:perform_in).and_raise(RedisClient::CannotConnectError)
    expect { create(:installment_event) }.to change(InstallmentEvent, :count).by(1)
  end
end
