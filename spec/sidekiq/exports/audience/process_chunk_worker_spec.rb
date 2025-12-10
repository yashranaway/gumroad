# frozen_string_literal: true

require "spec_helper"

describe Exports::Audience::ProcessChunkWorker do
  let(:seller) { create(:user) }
  let(:recipient) { create(:user) }
  let!(:follower1) { create(:active_follower, user: seller, email: "follower1@example.com", created_at: 1.day.ago) }
  let!(:follower2) { create(:active_follower, user: seller, email: "follower2@example.com", created_at: 2.days.ago) }
  let(:export) { create(:audience_export, seller:, recipient:, options: { "followers" => true }) }

  describe "#perform" do
    context "when there are still unprocessed chunks" do
      it "processes the chunk without triggering compile" do
        chunk1 = create(:audience_export_chunk, export:, member_ids: [seller.audience_members.first.id])
        chunk2 = create(:audience_export_chunk, export:, member_ids: [seller.audience_members.second.id])

        described_class.new.perform(chunk1.id)
        chunk1.reload

        expect(chunk1.processed).to be true
        expect(chunk1.members_data.size).to eq(1)
        expect(chunk1.members_data.first.first).to eq(seller.audience_members.first.email)

        expect(Exports::Audience::CompileChunksWorker.jobs.size).to eq(0)
      end
    end

    context "when all chunks are processed" do
      it "triggers the compile worker" do
        chunk = create(:audience_export_chunk, export:, member_ids: seller.audience_members.ids)

        described_class.new.perform(chunk.id)

        expect(Exports::Audience::CompileChunksWorker).to have_enqueued_sidekiq_job(export.id)
      end
    end
  end
end
