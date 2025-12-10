# frozen_string_literal: true

require "spec_helper"

describe Exports::AudienceExportService do
  describe "#perform" do
    let!(:user) { create(:user) }
    let!(:follower) { create(:active_follower, email: "follower@gumroad.com", user: user, created_at: 1.day.ago) }
    let(:product) { create(:product, user: user, name: "Product 1", price_cents: 100) }
    let!(:customer) { create(:purchase, seller: user, link: product, created_at: 2.days.ago) }
    let(:affiliate_user) { create(:affiliate_user, created_at: 4.days.ago) }
    let(:direct_affiliate) { create(:direct_affiliate, affiliate_user:, seller: user, created_at: 3.days.ago) }
    let!(:product_affiliate) { create(:product_affiliate, product:, affiliate: direct_affiliate, affiliate_basis_points: 10_00) }

    subject { described_class.new(user, options) }

    context "when options has followers" do
      let(:options) { { followers: true } }

      it "generates csv with followers" do
        rows = CSV.parse(subject.perform.tempfile.read)

        expect(rows.size).to eq(2)
        headers, data_row = rows.first, rows.second

        expect(headers).to eq(described_class::FIELDS)
        expect(data_row.first).to eq(follower.email)
        expect(data_row.second).to eq(follower.created_at.to_s)
      end
    end

    context "when options has customers" do
      let(:options) { { customers: true } }

      it "generates csv with customers" do
        rows = CSV.parse(subject.perform.tempfile.read)

        expect(rows.size).to eq(2)
        headers, data_row = rows.first, rows.second

        expect(headers).to eq(described_class::FIELDS)
        expect(data_row.first).to eq(customer.email)
        expect(data_row.second).to eq(customer.created_at.to_s)
      end
    end

    context "when options has affiliates" do
      let(:options) { { affiliates: true } }

      it "generates csv with customers" do
        rows = CSV.parse(subject.perform.tempfile.read)

        expect(rows.size).to eq(2)
        headers, data_row = rows.first, rows.second

        expect(headers).to eq(described_class::FIELDS)
        expect(data_row.first).to eq(affiliate_user.email)
        expect(data_row.second).to eq(direct_affiliate.created_at.to_s)
      end
    end

    context "when options has all audience types" do
      let(:options) { { followers: true, customers: true, affiliates: true } }

      it "generates csv with all audience types" do
        rows = CSV.parse(subject.perform.tempfile.read)

        expect(rows.size).to eq(4)
        headers = rows.first

        expect(headers).to eq(described_class::FIELDS)
        expect(rows[1].first).to eq(follower.email)
        expect(rows[1].second).to eq(follower.created_at.to_s)
        expect(rows[2].first).to eq(customer.email)
        expect(rows[2].second).to eq(customer.created_at.to_s)
        expect(rows[3].first).to eq(affiliate_user.email)
        expect(rows[3].second).to eq(direct_affiliate.created_at.to_s)
      end
    end

    context "when user is both a follower and a customer" do
      let(:options) { { followers: true, customers: true } }
      let!(:follower_customer) { create(:active_follower, email: customer.email, user:, created_at: 1000.day.ago) }

      it "generates csv with unique entries with minimum created_at" do
        rows = CSV.parse(subject.perform.tempfile.read)

        expect(rows.size).to eq(3)
        headers = rows.first

        expect(headers).to eq(described_class::FIELDS)
        expect(rows[1].first).to eq(follower.email)
        expect(rows[1].second).to eq(follower.created_at.to_s)
        expect(rows[2].first).to eq(follower_customer.email)
        expect(rows[2].second).to eq(follower_customer.created_at.to_s)
      end
    end

    context "when no options are provided" do
      let(:options) { {} }

      it "raises an ArgumentError" do
        expect { described_class.new(user, {}) }.to raise_error(ArgumentError, "At least one audience type (followers, customers, or affiliates) must be selected")
      end
    end
  end

  describe ".export" do
    let(:seller) { create(:user) }
    let(:recipient) { create(:user) }
    let(:options) { { followers: true } }

    context "when audience count is below threshold" do
      before do
        create(:active_follower, user: seller)
      end

      it "returns the service result synchronously" do
        result = described_class.export(seller:, recipient:, options:)

        expect(result).to be_a(described_class)
        expect(result.tempfile).to be_present
      end

      it "does not create an AudienceExport record" do
        expect { described_class.export(seller:, recipient:, options:) }
          .not_to change(AudienceExport, :count)
      end
    end

    context "when audience count exceeds threshold" do
      before do
        stub_const("#{described_class}::SYNCHRONOUS_EXPORT_THRESHOLD", 0)
        create(:active_follower, user: seller)
      end

      it "returns false" do
        result = described_class.export(seller:, recipient:, options:)
        expect(result).to be false
      end

      it "creates an AudienceExport record" do
        expect { described_class.export(seller:, recipient:, options:) }
          .to change(AudienceExport, :count).by(1)
      end

      it "enqueues the CreateAndEnqueueChunksWorker" do
        described_class.export(seller:, recipient:, options:)
        expect(Exports::Audience::CreateAndEnqueueChunksWorker).to have_enqueued_sidekiq_job(AudienceExport.last.id)
      end
    end
  end

  describe ".compile" do
    it "generates a CSV tempfile from members data enumerator" do
      data = [["user1@example.com", "2024-01-01 00:00:00"], ["user2@example.com", "2024-01-02 00:00:00"]]
      enumerator = data.each

      result = described_class.compile(enumerator)

      expect(result).to be_a(Tempfile)
      rows = CSV.parse(result.read)
      expect(rows.size).to eq(3)
      expect(rows[0]).to eq(described_class::FIELDS)
      expect(rows[1]).to eq(["user1@example.com", "2024-01-01 00:00:00"])
      expect(rows[2]).to eq(["user2@example.com", "2024-01-02 00:00:00"])
    end
  end
end
