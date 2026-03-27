# frozen_string_literal: true

require "spec_helper"

describe "Product custom domain short links", type: :request do
  let(:product) { create(:product) }
  let!(:custom_domain) { create(:custom_domain, domain: "example.com", user: nil, product:) }

  describe "GET /l/:id" do
    it "renders the product page" do
      get "/l/#{product.unique_permalink}", headers: { "HOST" => custom_domain.domain }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(product.name)
    end
  end

  describe "GET /l/:id/:code" do
    it "renders the product page and sets noindex header" do
      get "/l/#{product.unique_permalink}/SAVE10", headers: { "HOST" => custom_domain.domain }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(product.name)
      expect(response.headers["X-Robots-Tag"]).to eq("noindex")
    end
  end
end
