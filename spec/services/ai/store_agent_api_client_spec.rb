# frozen_string_literal: true

require "spec_helper"

describe Ai::StoreAgentApiClient do
  let(:seller) { create(:user) }
  let(:pundit_user) { SellerContext.new(user: seller, seller:) }

  def agent_application
    described_class.new(seller:, pundit_user:).send(:agent_application)
  end

  def create_matching_agent_app(**attrs)
    create(
      :oauth_application,
      {
        owner: seller,
        owner_type: "User",
        name: described_class::AGENT_APP_NAME,
        redirect_uri: described_class::AGENT_APP_REDIRECT_URI,
        scopes: described_class::AGENT_APP_SCOPES,
      }.merge(attrs),
    )
  end

  describe "#agent_application" do
    it "creates a flagged app when the seller has none" do
      application = nil

      expect { application = agent_application }.to change { seller.oauth_applications.count }.by(1)

      expect(application).to have_attributes(
        owner: seller,
        owner_type: "User",
        name: described_class::AGENT_APP_NAME,
        redirect_uri: described_class::AGENT_APP_REDIRECT_URI,
        is_first_party_agent_app: true,
      )
      expect(application.scopes.to_s).to eq(described_class::AGENT_APP_SCOPES)
    end

    it "finds the flagged app on the second call without creating a duplicate" do
      first_application = agent_application
      second_application = nil

      expect { second_application = agent_application }.not_to change { seller.oauth_applications.count }

      expect(second_application).to eq(first_application)
    end

    it "adopts a fingerprint-matching unflagged app and sets the flag" do
      unflagged_application = create_matching_agent_app
      application = nil

      expect { application = agent_application }.not_to change { seller.oauth_applications.count }

      expect(application).to eq(unflagged_application)
      expect(unflagged_application.reload.is_first_party_agent_app?).to be(true)
    end

    it "creates a new flagged app beside a same-name app with a different redirect URI" do
      seller_application = create_matching_agent_app(redirect_uri: "https://example.com/oauth/callback")
      application = nil

      expect { application = agent_application }.to change { seller.oauth_applications.count }.by(1)

      expect(application).not_to eq(seller_application)
      expect(application).to have_attributes(
        redirect_uri: described_class::AGENT_APP_REDIRECT_URI,
        is_first_party_agent_app: true,
      )
      expect(seller_application.reload.is_first_party_agent_app?).to be(false)
    end

    it "creates a new flagged app beside a same-name app with different scopes" do
      seller_application = create_matching_agent_app(scopes: "account")
      application = nil

      expect { application = agent_application }.to change { seller.oauth_applications.count }.by(1)

      expect(application).not_to eq(seller_application)
      expect(application).to have_attributes(
        is_first_party_agent_app: true,
      )
      expect(application.scopes.to_s).to eq(described_class::AGENT_APP_SCOPES)
      expect(seller_application.reload.is_first_party_agent_app?).to be(false)
    end

    it "creates a new flagged app beside a soft-deleted fingerprint-matching app" do
      deleted_application = create_matching_agent_app
      deleted_application.update_column(:deleted_at, Time.current)
      application = nil

      expect { application = agent_application }.to change { seller.oauth_applications.count }.by(1)

      expect(application).not_to eq(deleted_application)
      expect(application).to have_attributes(
        deleted_at: nil,
        is_first_party_agent_app: true,
      )
      expect(deleted_application.reload.is_first_party_agent_app?).to be(false)
    end

    it "creates a fresh app when the only flagged app has been soft-deleted" do
      flagged_then_deleted = agent_application
      flagged_then_deleted.update_column(:deleted_at, Time.current)
      application = nil

      expect { application = described_class.new(seller:, pundit_user:).send(:agent_application) }
        .to change { seller.oauth_applications.count }.by(1)

      expect(application).not_to eq(flagged_then_deleted)
      expect(application).to have_attributes(deleted_at: nil, is_first_party_agent_app: true)
    end

    # A seller can set name and redirect_uri from Settings > Advanced but never scopes, so the scope
    # string is the last barrier stopping a seller-made app from satisfying the adoption fingerprint.
    # If public_scopes ever grows to equal the agent's set, adoption reopens.
    it "keeps the agent's scope superset distinct from the publicly grantable scopes" do
      expect(described_class::AGENT_APP_SCOPES).not_to eq(Doorkeeper.configuration.public_scopes.to_s)
    end
  end

  # Only an endpoint that opts in gets a JSON body. Everything else keeps the form encoding the v2
  # API's string-parsed boolean params depend on (`params[:metadata_only] == "true"`), so this is
  # green for a scalar body and JSON only when asked.
  describe "#write body encoding" do
    let(:client) { described_class.new(seller:, pundit_user:) }

    def captured_put_options(json_body:)
      captured = nil
      session = double("integration session")
      allow(ActionDispatch::Integration::Session).to receive(:new).and_return(session)
      allow(session).to receive(:host!)
      allow(session).to receive(:put) { |_path, **options| captured = options }
      allow(session).to receive(:response).and_return(double(body: "{}", status: 200))

      client.write(:put, "/products/product-id/sections", { "sections" => [] }, json_body:)

      captured
    end

    it "form-encodes the body by default" do
      options = captured_put_options(json_body: false)

      expect(options).not_to have_key(:as)
      expect(options[:params]).to eq("sections" => [])
    end

    it "sends a JSON body when the endpoint opts in, so an empty list survives the transport" do
      expect(captured_put_options(json_body: true)).to include(as: :json)
    end
  end

  # The revoke is cleanup, not part of the response: a deadlock on the token row used to escape the
  # `ensure` and fail a tool call that had already succeeded.
  describe "#request token cleanup" do
    let(:client) { described_class.new(seller:, pundit_user:) }

    def stub_agent_get!(token)
      session = double("integration session")
      allow(ActionDispatch::Integration::Session).to receive(:new).and_return(session)
      allow(session).to receive(:host!)
      allow(session).to receive(:get)
      allow(session).to receive(:response).and_return(double(body: "{}", status: 200))
      allow(client).to receive(:agent_application).and_return(create_matching_agent_app)
      allow(Doorkeeper::AccessToken).to receive(:create!).and_return(token)

      client.get("/products")
    end

    it "retries a deadlocked revoke instead of failing the call" do
      token = double("access token", token: "agent-token")
      revokes = 0
      allow(token).to receive(:revoke) do
        revokes += 1
        raise ActiveRecord::Deadlocked, "Deadlock found when trying to get lock" if revokes == 1
      end

      expect { stub_agent_get!(token) }.not_to raise_error
      expect(revokes).to eq(2)
    end

    it "swallows a revoke that deadlocks every time" do
      token = double("access token", token: "agent-token")
      allow(token).to receive(:revoke).and_raise(ActiveRecord::Deadlocked.new("Deadlock found"))

      expect { stub_agent_get!(token) }.not_to raise_error
    end
  end
end
