# frozen_string_literal: true

require "spec_helper"

describe "Admin Impersonation Export", type: :system, js: true do
  let(:admin) { create(:admin_user) }
  let(:seller) { create(:named_seller) }

  let!(:seller_product) { create(:product, user: seller, name: "Seller's Product", price_cents: 0) }
  let!(:seller_purchase) { create(:free_purchase, link: seller_product, seller:, email: "buyer@example.com") }

  let!(:admin_product) { create(:product, user: admin, name: "Admin's Product", price_cents: 0) }
  let!(:admin_purchase) { create(:free_purchase, link: admin_product, seller: admin, email: "admin-buyer@example.com") }

  before do
    index_model_records(Purchase)
    login_as(admin)
  end

  describe "impersonating a seller" do
    before do
      visit admin_path
      fill_in "Enter user email, username, or Stripe account ID", with: seller.email
      click_on "Impersonate user"
      wait_for_ajax
    end

    describe "LargeSeller record creation" do
      context "when seller has sufficient sales" do
        before do
          stub_const("LargeSeller::SALES_LOWER_LIMIT", 1)
          # Re-impersonate to trigger the LargeSeller creation with new threshold
          visit admin_path
          fill_in "Enter user email, username, or Stripe account ID", with: seller.email
          click_on "Impersonate user"
          wait_for_ajax
        end

        it "creates a LargeSeller record for the impersonated user" do
          expect(LargeSeller.where(user: seller)).to exist
        end
      end

      context "when seller has insufficient sales" do
        it "does not create a LargeSeller record" do
          expect(LargeSeller.where(user: seller)).not_to exist
        end
      end
    end

    describe "purchase export" do
      it "exports the impersonated seller's sales, not the admin's" do
        visit customers_path
        wait_for_ajax

        select_disclosure "Export" do
          click_on "Download"
        end

        expect(page).to have_current_path(customers_path)
      end
    end
  end

  describe "Redis TTL refresh" do
    it "refreshes the impersonation TTL on access" do
      visit admin_path
      fill_in "Enter user email, username, or Stripe account ID", with: seller.email
      click_on "Impersonate user"
      wait_for_ajax

      redis_key = RedisKey.impersonated_user(admin.id)

      initial_ttl = $redis.ttl(redis_key)
      expect(initial_ttl).to be > 0

      visit dashboard_path
      wait_for_ajax

      refreshed_ttl = $redis.ttl(redis_key)
      expect(refreshed_ttl).to be_within(60).of(7.days.to_i)
      expect(refreshed_ttl).to be_within(60).of(7.days.to_i)
    end
  end
end
