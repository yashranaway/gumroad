# frozen_string_literal: true

require "spec_helper"

describe AudienceExport do
  describe "associations" do
    it "belongs to seller" do
      expect(described_class.reflect_on_association(:seller).macro).to eq(:belongs_to)
    end

    it "belongs to recipient" do
      expect(described_class.reflect_on_association(:recipient).macro).to eq(:belongs_to)
    end

    it "has many chunks" do
      expect(described_class.reflect_on_association(:chunks).macro).to eq(:has_many)
    end
  end

  describe "validations" do
    it "requires options" do
      export = build(:audience_export, options: nil)
      expect(export).not_to be_valid
      expect(export.errors[:options]).to be_present
    end
  end

  describe "dependent destroy" do
    it "deletes chunks when export is destroyed" do
      export = create(:audience_export)
      create(:audience_export_chunk, export:)
      create(:audience_export_chunk, export:)

      expect { export.destroy }.to change(AudienceExportChunk, :count).by(-2)
    end
  end
end
