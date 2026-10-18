# frozen_string_literal: true

require "spec_helper"

# spec_helper swaps SsrfFilter.get for an HTTParty call so specs can reach localhost and Minio
# without the SSRF filter's DNS checks. Callers branch on the Net::HTTPResponse the gem hands
# back — `is_a?(Net::HTTPOK)`, `is_a?(Net::HTTPRedirection)`, `["location"]`, `body` — so the
# double has to return that same object, not HTTParty's wrapper around it.
describe "the global SsrfFilter double", type: :request do
  it "returns the raw Net::HTTPResponse the gem returns" do
    stub_request(:get, "http://ssrf-double.test/l/sample.json").to_return(status: 200, body: "{}")

    response = SsrfFilter.get("http://ssrf-double.test/l/sample.json")

    expect(response).to be_a(Net::HTTPOK)
    expect(response.body).to eq("{}")
  end
end
