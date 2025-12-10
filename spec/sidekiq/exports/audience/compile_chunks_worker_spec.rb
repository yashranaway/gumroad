# frozen_string_literal: true

require "spec_helper"

describe Exports::Audience::CompileChunksWorker do
  let(:seller) { create(:user) }
  let(:recipient) { create(:user) }
  let(:export) { create(:audience_export, seller:, recipient:, options: { "followers" => true }) }

  before do
    ActionMailer::Base.deliveries.clear
  end

  describe "#perform" do
    it "compiles chunks into CSV and sends email" do
      chunk1 = create(:audience_export_chunk, export:, members_data: [["user1@example.com", "2024-01-01 00:00:00"]], processed: true, revision: REVISION)
      chunk2 = create(:audience_export_chunk, export:, members_data: [["user2@example.com", "2024-01-02 00:00:00"]], processed: true, revision: REVISION)

      expect(ContactingCreatorMailer).to receive(:subscribers_data).and_call_original

      described_class.new.perform(export.id)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([recipient.email])

      expect(AudienceExport.exists?(export.id)).to be false
      expect(AudienceExportChunk.exists?(chunk1.id)).to be false
      expect(AudienceExportChunk.exists?(chunk2.id)).to be false
    end

    it "generates correct filename format" do
      create(:audience_export_chunk, export:, members_data: [["user@example.com", "2024-01-01"]], processed: true)

      described_class.new.perform(export.id)

      mail = ActionMailer::Base.deliveries.last
      attachment_or_body = mail.attachments.first&.filename || mail.body.to_s
      expect(attachment_or_body).to include("Subscribers-#{seller.username}")
    end
  end
end
