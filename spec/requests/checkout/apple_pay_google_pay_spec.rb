# frozen_string_literal: true

require "spec_helper"

describe "Checkout with Apple Pay and Google Pay", :js, type: :system do
  let(:product) { create(:product, price_cents: 2000) }

  let(:stripe_mock_script) do
    <<~JS
      window.mockStripePaymentRequest = (options = {}) => {
        const { applePay = false, googlePay = false, showError = null } = options;

        const mockPaymentRequest = {
          canMakePayment: () => Promise.resolve({ applePay, googlePay }),
          on: (event, cb) => {
            if (event === 'paymentmethod') {
              window.__triggerPaymentMethod = cb;
            }
          },
          show: () => showError ? Promise.reject(new Error(showError)) : Promise.resolve(),
          update: () => {},
        };

        window.Stripe = (key, options) => {
          const stripeInstance = {
            elements: () => ({
              create: () => ({
                mount: (selector) => {
                  const container = document.querySelector(selector);
                  if (container) {
                    container.innerHTML = '<button type="button">Pay</button>';
                  }
                },
                on: () => {},
                destroy: () => {},
                update: () => {},
              }),
              getElement: () => null,
            }),
          };

          stripeInstance.paymentRequest = () => mockPaymentRequest;

          return stripeInstance;
        };
      };
    JS
  end

  it "shows Apple Pay button and simulates payment unavailable error" do
    visit "/l/#{product.unique_permalink}"
    add_to_cart(product)

    page.execute_script(stripe_mock_script)
    page.execute_script(<<~JS)
      window.mockStripePaymentRequest({
        applePay: true,
        showError: 'Payment request is not available'
      });
    JS

    apple_pay_radio = find("[role=radio]", text: "Apple Pay", wait: 5)
    apple_pay_radio.click

    fill_in "Email address", with: "test@example.com"
    unfocus

    pay_buttons = all("button", text: "Pay", visible: true)
    expect(pay_buttons.length).to eq(1)

    pay_buttons.first.click
    expect(page).to have_text("Sorry, something went wrong")
  end

  it "shows Google Pay button and simulates payment unavailable error" do
    visit "/l/#{product.unique_permalink}"
    add_to_cart(product)

    page.execute_script(stripe_mock_script)
    page.execute_script(<<~JS)
      window.mockStripePaymentRequest({
        googlePay: true,
        showError: 'Payment request is not available'
      });
    JS

    google_pay_radio = find("[role=radio]", text: "Google Pay", wait: 5)
    google_pay_radio.click

    fill_in "Email address", with: "test@example.com"
    unfocus

    pay_buttons = all("button", text: "Pay", visible: true)
    expect(pay_buttons.length).to eq(1)

    pay_buttons.first.click
    expect(page).to have_text("Sorry, something went wrong")
  end
end
