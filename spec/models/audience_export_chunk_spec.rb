# frozen_string_literal: true

require "spec_helper"

describe AudienceExportChunk do
  describe "associations" do
    it "belongs to export" do
      expect(described_class.reflect_on_association(:export).macro).to eq(:belongs_to)
    end
  end

  describe "serialization" do
    it "serializes member_ids as array" do
      chunk = create(:audience_export_chunk, member_ids: [1, 2, 3])
      chunk.reload
      expect(chunk.member_ids).to eq([1, 2, 3])
    end

    it "serializes members_data as array" do
      data = [["test@example.com", Time.current.to_s]]
      chunk = create(:audience_export_chunk, members_data: data)
      chunk.reload
      expect(chunk.members_data).to eq(data)
    end
  end
end
