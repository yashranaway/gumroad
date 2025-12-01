# frozen_string_literal: true

require "spec_helper"

describe "Checkout with Apple Pay and Google Pay", :js, type: :system do
  before do
    @product = create(:product, price_cents: 2000)
  end

  it "does not show duplicate Pay buttons" do
    visit "/l/#{@product.unique_permalink}"
    add_to_cart(@product)

    fill_in "Email address", with: "test@example.com"
    unfocus

    pay_buttons = all("button", text: "Pay", visible: true)
    expect(pay_buttons.length).to eq(1)
  end

  context "with physical product requiring shipping" do
    before do
      @physical_product = create(:physical_product, price_cents: 3000, require_shipping: true)
    end

    it "shows shipping information and single Pay button" do
      visit "/l/#{@physical_product.unique_permalink}"
      add_to_cart(@physical_product)

      fill_in "Email address", with: "test@example.com"
      unfocus

      expect(page).to have_text "Shipping information"

      pay_buttons = all("button", text: "Pay", visible: true)
      expect(pay_buttons.length).to eq(1)
    end
  end
end
