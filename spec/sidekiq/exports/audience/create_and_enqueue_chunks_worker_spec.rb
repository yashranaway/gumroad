# frozen_string_literal: true

require "spec_helper"

describe Exports::Audience::CreateAndEnqueueChunksWorker do
  let(:seller) { create(:user) }
  let(:recipient) { create(:user) }
  let!(:follower1) { create(:active_follower, user: seller, created_at: 1.day.ago) }
  let!(:follower2) { create(:active_follower, user: seller, created_at: 2.days.ago) }
  let!(:follower3) { create(:active_follower, user: seller, created_at: 3.days.ago) }

  before do
    stub_const("#{described_class}::MAX_MEMBERS_PER_CHUNK", 2)
  end

  it "creates and enqueues a job for each generated chunk" do
    export = create(:audience_export, seller:, recipient:, options: { "followers" => true })

    described_class.new.perform(export.id)
    export.reload

    expect(export.chunks.count).to eq(2)
    expect(export.chunks.first.member_ids.size).to eq(2)
    expect(export.chunks.second.member_ids.size).to eq(1)

    expect(Exports::Audience::ProcessChunkWorker).to have_enqueued_sidekiq_job(export.chunks.first.id)
    expect(Exports::Audience::ProcessChunkWorker).to have_enqueued_sidekiq_job(export.chunks.second.id)
  end

  it "clears stale chunks on retry" do
    export = create(:audience_export, seller:, recipient:, options: { "followers" => true })
    stale_chunk = create(:audience_export_chunk, export:, member_ids: [999])

    described_class.new.perform(export.id)
    export.reload

    expect(export.chunks.count).to eq(2)
    expect(AudienceExportChunk.exists?(stale_chunk.id)).to be false
  end
end
