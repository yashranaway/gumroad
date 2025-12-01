# frozen_string_literal: true

require "spec_helper"

describe "Checkout with Apple Pay and Google Pay", :js, type: :system do
  before do
    @product = create(:product, price_cents: 2000)
  end

  let(:stripe_mock_script) do
    <<~JS
      window.mockStripePaymentRequest = (options = {}) => {
        const { applePay = false, googlePay = false } = options;

        const mockPaymentRequest = {
          canMakePayment: () => Promise.resolve({ applePay, googlePay }),
          on: (event, cb) => {
            if (event === 'paymentmethod') {
              window.__triggerPaymentMethod = cb;
            }
          },
          show: () => Promise.resolve(),
          update: () => {},
        };

        const originalStripe = window.Stripe;

        window.Stripe = (key, options) => {
          const stripeInstance = originalStripe ? originalStripe(key, options) : {
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

  it "shows Apple Pay button and hides duplicate Pay button" do
    visit "/l/#{@product.unique_permalink}"

    page.execute_script(stripe_mock_script)
    page.execute_script("window.mockStripePaymentRequest({ applePay: true });")

    add_to_cart(@product)

    apple_pay_radio = find("[role=radio]", text: "Apple Pay", wait: 5)
    apple_pay_radio.click

    fill_in "Email address", with: "test@example.com"
    unfocus

    pay_buttons = all("button", text: "Pay", visible: true)
    expect(pay_buttons.length).to eq(1)
  end

  it "shows Google Pay button and hides duplicate Pay button" do
    visit "/l/#{@product.unique_permalink}"

    page.execute_script(stripe_mock_script)
    page.execute_script("window.mockStripePaymentRequest({ googlePay: true });")

    add_to_cart(@product)

    google_pay_radio = find("[role=radio]", text: "Google Pay", wait: 5)
    google_pay_radio.click

    fill_in "Email address", with: "test@example.com"
    unfocus

    pay_buttons = all("button", text: "Pay", visible: true)
    expect(pay_buttons.length).to eq(1)
  end
end
