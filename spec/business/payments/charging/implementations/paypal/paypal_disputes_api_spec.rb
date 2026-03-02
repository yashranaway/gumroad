# frozen_string_literal: true

describe PaypalDisputesApi do
  let(:api) { PaypalDisputesApi.new }
  let(:paypal_auth_token) { "Bearer test_token" }
  let(:merchant_account) { create(:merchant_account_paypal, charge_processor_merchant_id: "TEST_MERCHANT_ID") }
  let(:dispute_id) { "PP-D-12345" }

  before do
    allow_any_instance_of(PaypalPartnerRestCredentials).to receive(:auth_token).and_return(paypal_auth_token)
  end

  describe "#provide_evidence" do
    let(:tracking_info) do
      {
        carrier_name: "FEDEX",
        tracking_number: "123456789",
        ship_date: "2024-01-15"
      }
    end
    let(:notes) { "Digital product was delivered via download link." }

    context "when evidence submission succeeds" do
      let(:successful_response) do
        OpenStruct.new(
          status_code: 200,
          result: OpenStruct.new(
            links: [{ rel: "self", href: "https://api.paypal.com/v1/customer/disputes/#{dispute_id}" }]
          )
        )
      end

      before do
        allow_any_instance_of(PayPal::PayPalHttpClient).to receive(:execute).and_return(successful_response)
      end

      it "returns a successful response with tracking info" do
        response = api.provide_evidence(
          dispute_id:,
          merchant_account:,
          tracking_info:,
          notes:
        )

        expect(response.status_code).to eq(200)
        expect(api.successful_response?(response)).to be true
      end

      it "returns a successful response with notes only (digital products)" do
        response = api.provide_evidence(
          dispute_id:,
          merchant_account:,
          tracking_info: nil,
          notes:
        )

        expect(response.status_code).to eq(200)
        expect(api.successful_response?(response)).to be true
      end

      it "sets evidence_type to PROOF_OF_FULFILLMENT when tracking info is present" do
        expect_any_instance_of(PayPal::PayPalHttpClient).to receive(:execute) do |_client, request|
          evidence = request.body[:evidences].first
          expect(evidence[:evidence_type]).to eq("PROOF_OF_FULFILLMENT")
          expect(evidence[:evidence_info]).to eq({ tracking_info: [tracking_info] })
          successful_response
        end.and_return(successful_response)

        api.provide_evidence(
          dispute_id:,
          merchant_account:,
          tracking_info:,
          notes:
        )
      end

      it "sets evidence_type to OTHER when no tracking info" do
        expect_any_instance_of(PayPal::PayPalHttpClient).to receive(:execute) do |_client, request|
          evidence = request.body[:evidences].first
          expect(evidence[:evidence_type]).to eq("OTHER")
          expect(evidence[:evidence_info]).to be_nil
          successful_response
        end.and_return(successful_response)

        api.provide_evidence(
          dispute_id:,
          merchant_account:,
          tracking_info: nil,
          notes:
        )
      end

      it "truncates notes to 2000 characters" do
        long_notes = "a" * 3000

        expect_any_instance_of(PayPal::PayPalHttpClient).to receive(:execute) do |_client, request|
          evidence = request.body[:evidences].first
          expect(evidence[:notes].length).to eq(2000)
          successful_response
        end.and_return(successful_response)

        api.provide_evidence(
          dispute_id:,
          merchant_account:,
          tracking_info: nil,
          notes: long_notes
        )
      end

      it "includes PayPal-Auth-Assertion header for merchant" do
        expect_any_instance_of(PayPal::PayPalHttpClient).to receive(:execute) do |_client, request|
          expect(request.headers["PayPal-Auth-Assertion"]).to be_present
          expect(request.headers["PayPal-Auth-Assertion"]).to include(Base64.strict_encode64({ payer_id: "TEST_MERCHANT_ID", iss: PAYPAL_PARTNER_CLIENT_ID }.to_json))
          successful_response
        end.and_return(successful_response)

        api.provide_evidence(dispute_id:, merchant_account:, notes:)
      end

      it "includes PayPal-Request-Id header for idempotency" do
        expect_any_instance_of(PayPal::PayPalHttpClient).to receive(:execute) do |_client, request|
          expect(request.headers["PayPal-Request-Id"]).to eq("gumroad-dispute-evidence-#{dispute_id}")
          successful_response
        end.and_return(successful_response)

        api.provide_evidence(dispute_id:, merchant_account:, notes:)
      end

      it "accepts evidence_type parameter for dispute reason mapping" do
        expect_any_instance_of(PayPal::PayPalHttpClient).to receive(:execute) do |_client, request|
          evidence = request.body[:evidences].first
          expect(evidence[:evidence_type]).to eq("PROOF_OF_REFUND")
          successful_response
        end.and_return(successful_response)

        api.provide_evidence(
          dispute_id:,
          merchant_account:,
          evidence_type: "PROOF_OF_REFUND",
          tracking_info: nil,
          notes:
        )
      end

      it "overrides evidence_type to PROOF_OF_FULFILLMENT when tracking info present" do
        expect_any_instance_of(PayPal::PayPalHttpClient).to receive(:execute) do |_client, request|
          evidence = request.body[:evidences].first
          expect(evidence[:evidence_type]).to eq("PROOF_OF_FULFILLMENT")
          successful_response
        end.and_return(successful_response)

        api.provide_evidence(
          dispute_id:,
          merchant_account:,
          evidence_type: "OTHER",
          tracking_info:,
          notes:
        )
      end
    end

    context "when evidence submission fails" do
      it "returns error response for permission denied (403)" do
        error_response = OpenStruct.new(
          status_code: 403,
          result: OpenStruct.new(
            name: "PERMISSION_DENIED",
            message: "You don't have permission to access this resource"
          )
        )

        allow_any_instance_of(PayPal::PayPalHttpClient).to receive(:execute).and_return(error_response)

        response = api.provide_evidence(dispute_id:, merchant_account:, notes:)

        expect(response.status_code).to eq(403)
        expect(api.successful_response?(response)).to be false
      end

      it "returns error response for dispute not found (404)" do
        error_response = OpenStruct.new(
          status_code: 404,
          result: OpenStruct.new(
            name: "INVALID_DISPUTE_ID",
            message: "Dispute not found"
          )
        )

        allow_any_instance_of(PayPal::PayPalHttpClient).to receive(:execute).and_return(error_response)

        response = api.provide_evidence(dispute_id:, merchant_account:, notes:)

        expect(response.status_code).to eq(404)
        expect(api.successful_response?(response)).to be false
      end

      it "returns error response for dispute not eligible (422)" do
        error_response = OpenStruct.new(
          status_code: 422,
          result: OpenStruct.new(
            name: "DISPUTE_NOT_ELIGIBLE_FOR_EVIDENCE",
            message: "Dispute is not eligible for evidence submission",
            details: [OpenStruct.new(description: "The dispute is already closed")]
          )
        )

        allow_any_instance_of(PayPal::PayPalHttpClient).to receive(:execute).and_return(error_response)

        response = api.provide_evidence(dispute_id:, merchant_account:, notes:)

        expect(response.status_code).to eq(422)
        expect(api.successful_response?(response)).to be false
      end

      it "handles PayPal HTTP errors gracefully" do
        allow_any_instance_of(PayPal::PayPalHttpClient).to receive(:execute).and_raise(
          PayPalHttp::HttpError.new(500, OpenStruct.new(name: "INTERNAL_ERROR"), {})
        )

        response = api.provide_evidence(dispute_id:, merchant_account:, notes:)

        expect(response.status_code).to eq(500)
        expect(api.successful_response?(response)).to be false
      end
    end
  end

  describe "#accept_claim" do
    context "when accept claim succeeds" do
      let(:successful_response) do
        OpenStruct.new(
          status_code: 200,
          result: OpenStruct.new(
            links: [{ rel: "self", href: "https://api.paypal.com/v1/customer/disputes/#{dispute_id}" }]
          )
        )
      end

      before do
        allow_any_instance_of(PayPal::PayPalHttpClient).to receive(:execute).and_return(successful_response)
      end

      it "sends POST request to accept-claim endpoint" do
        expect_any_instance_of(PayPal::PayPalHttpClient).to receive(:execute) do |_client, request|
          expect(request.path).to eq("/v1/customer/disputes/#{dispute_id}/accept-claim")
          expect(request.verb).to eq("POST")
          successful_response
        end.and_return(successful_response)

        api.accept_claim(dispute_id:, merchant_account:)
      end

      it "includes idempotency key header" do
        expect_any_instance_of(PayPal::PayPalHttpClient).to receive(:execute) do |_client, request|
          expect(request.headers["PayPal-Request-Id"]).to eq("gumroad-dispute-accept-#{dispute_id}")
          successful_response
        end.and_return(successful_response)

        api.accept_claim(dispute_id:, merchant_account:)
      end

      it "includes note in body when provided" do
        expect_any_instance_of(PayPal::PayPalHttpClient).to receive(:execute) do |_client, request|
          expect(request.body[:note]).to eq("Seller accepted the claim.")
          successful_response
        end.and_return(successful_response)

        api.accept_claim(dispute_id:, merchant_account:, note: "Seller accepted the claim.")
      end

      it "returns successful response" do
        response = api.accept_claim(dispute_id:, merchant_account:)
        expect(api.successful_response?(response)).to be true
      end
    end

    context "when accept claim fails" do
      it "handles PayPal HTTP errors gracefully" do
        allow_any_instance_of(PayPal::PayPalHttpClient).to receive(:execute).and_raise(
          PayPalHttp::HttpError.new(422, OpenStruct.new(name: "DISPUTE_ALREADY_RESOLVED"), {})
        )

        response = api.accept_claim(dispute_id:, merchant_account:)
        expect(response.status_code).to eq(422)
        expect(api.successful_response?(response)).to be false
      end
    end
  end

  describe "#get_dispute" do
    context "when request succeeds" do
      let(:successful_response) do
        OpenStruct.new(
          status_code: 200,
          result: OpenStruct.new(
            dispute_id:,
            status: "OPEN",
            reason: "MERCHANDISE_OR_SERVICE_NOT_RECEIVED"
          )
        )
      end

      before do
        allow_any_instance_of(PayPal::PayPalHttpClient).to receive(:execute).and_return(successful_response)
      end

      it "returns dispute details" do
        response = api.get_dispute(dispute_id:, merchant_account:)

        expect(response.status_code).to eq(200)
        expect(response.result.dispute_id).to eq(dispute_id)
        expect(response.result.status).to eq("OPEN")
      end
    end
  end

  describe "#successful_response?" do
    it "returns true for 2xx status codes" do
      [200, 201, 204].each do |code|
        response = OpenStruct.new(status_code: code)
        expect(api.successful_response?(response)).to be true
      end
    end

    it "returns false for non-2xx status codes" do
      [400, 403, 404, 422, 500].each do |code|
        response = OpenStruct.new(status_code: code)
        expect(api.successful_response?(response)).to be false
      end
    end
  end
end
