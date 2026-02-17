# frozen_string_literal: true

class PaypalDisputesApi
  def initialize
    paypal_environment = Rails.env.production? ?
                             PayPal::LiveEnvironment.new(PAYPAL_PARTNER_CLIENT_ID, PAYPAL_PARTNER_CLIENT_SECRET) :
                             PayPal::SandboxEnvironment.new(PAYPAL_PARTNER_CLIENT_ID, PAYPAL_PARTNER_CLIENT_SECRET)
    @paypal_client = PayPal::PayPalHttpClient.new(paypal_environment)
  end

  def provide_evidence(dispute_id:, merchant_account:, evidence_type: "OTHER", tracking_info: nil, notes: nil)
    @request = new_request(path: "/v1/customer/disputes/#{dispute_id}/provide-evidence", verb: "POST")
    @request.headers["PayPal-Auth-Assertion"] = paypal_auth_assertion_header(merchant_account.charge_processor_merchant_id)
    @request.headers["PayPal-Request-Id"] = generate_idempotency_key(dispute_id)

    body = {}
    body[:evidence_type] = determine_evidence_type(evidence_type, tracking_info)
    body[:evidence_info] = { tracking_info: [tracking_info] } if tracking_info.present?
    body[:notes] = notes.to_s[0...2000] if notes.present?

    @request.body = body
    execute_request
  end

  def get_dispute(dispute_id:, merchant_account:)
    @request = new_request(path: "/v1/customer/disputes/#{dispute_id}", verb: "GET")
    @request.headers["PayPal-Auth-Assertion"] = paypal_auth_assertion_header(merchant_account.charge_processor_merchant_id)
    execute_request
  end

  def successful_response?(api_response)
    (200...300).include?(api_response.status_code)
  end

  private
    def new_request(path:, verb:)
      OpenStruct.new(
        {
          path:,
          verb:,
          headers: rest_api_headers,
          body: {},
        }
      )
    end

    def rest_api_headers
      {
        "Accept" => "application/json",
        "Accept-Language" => "en_US",
        "Authorization" => PaypalPartnerRestCredentials.new.auth_token,
        "Content-Type" => "application/json",
        "PayPal-Partner-Attribution-Id" => PAYPAL_BN_CODE
      }
    end

    def paypal_auth_assertion_header(seller_merchant_id)
      header_part_one = { alg: "none" }.to_json
      header_part_two = { payer_id: seller_merchant_id, iss: PAYPAL_PARTNER_CLIENT_ID }.to_json
      "#{Base64.strict_encode64(header_part_one)}.#{Base64.strict_encode64(header_part_two)}."
    end

    def generate_idempotency_key(dispute_id)
      "gumroad-dispute-evidence-#{dispute_id}"
    end

    def determine_evidence_type(evidence_type, tracking_info)
      return "PROOF_OF_FULFILLMENT" if tracking_info.present?
      evidence_type.presence || "OTHER"
    end

    def execute_request
      Rails.logger.info "Making PayPal Disputes API request:: #{LogRedactor.redact(@request)}"
      @paypal_client.execute(@request)
    rescue PayPalHttp::HttpError => e
      Rails.logger.error "PayPal Disputes API request failed:: Status code: #{e.status_code}, Result: #{e.result.inspect}"
      OpenStruct.new(status_code: e.status_code, result: e.result)
    end
end
