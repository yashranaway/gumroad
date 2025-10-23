
require "spec_helper"

describe "Installment plan price protection" do
  let(:seller) { create(:user) }
  let(:product) { create(:product, user: seller, price_cents: 14700) }
  let(:installment_plan) { create(:product_installment_plan, link: product, number_of_installments: 3, recurrence: "monthly") }
  let(:subscription) { create(:subscription, link: product, user: seller) }
  let(:payment_option) { create(:payment_option, subscription: subscription, installment_plan: installment_plan) }

  describe "price change protection" do
    let!(:snapshot) do
      create(:installment_plan_snapshot,
             payment_option: payment_option,
             number_of_installments: 3,
             recurrence: "monthly",
             total_price_cents: 14700)
    end

    context "when product price increases" do
      it "protects existing customers from price increases" do
        # Snapshot created with original pricing
        expect(snapshot.total_price_cents).to eq(14700)
        expect(snapshot.number_of_installments).to eq(3)

        # Seller increases price from $147 to $197
        product.update!(price_cents: 19700)
        installment_plan.reload

        # Existing snapshot remains unchanged (price protection)
        snapshot.reload
        expect(snapshot.total_price_cents).to eq(14700)
        expect(snapshot.number_of_installments).to eq(3)

        # Calculate installment amounts from protected snapshot
        payments = snapshot.calculate_installment_payment_price_cents
        expect(payments).to eq([4900, 4900, 4900])
        expect(payments.sum).to eq(14700) # Original total protected
      end
    end

    context "when product price decreases" do
      it "maintains original pricing for existing customers" do
        # Seller decreases price from $147 to $100
        product.update!(price_cents: 10000)
        installment_plan.reload

        # Existing snapshot remains unchanged (no benefit from price decrease)
        snapshot.reload
        expect(snapshot.total_price_cents).to eq(14700)

        # Calculate installment amounts from protected snapshot
        payments = snapshot.calculate_installment_payment_price_cents
        expect(payments).to eq([4900, 4900, 4900])
        expect(payments.sum).to eq(14700) # Original total maintained
      end
    end
  end

  describe "installment configuration protection" do
    let!(:snapshot) do
      create(:installment_plan_snapshot,
             payment_option: payment_option,
             number_of_installments: 3,
             recurrence: "monthly",
             total_price_cents: 14700)
    end

    context "when installment count changes" do
      it "protects existing customers when count decreases from 3 to 2" do
        # Seller changes installment plan from 3 to 2 payments
        installment_plan.update!(number_of_installments: 2)

        # Existing snapshot remains unchanged (configuration protection)
        snapshot.reload
        expect(snapshot.number_of_installments).to eq(3)

        # Live plan should be updated for new customers
        expect(installment_plan.reload.number_of_installments).to eq(2)

        # Existing customer still gets 3 installments
        payments = snapshot.calculate_installment_payment_price_cents
        expect(payments.length).to eq(3)
        expect(payments).to eq([4900, 4900, 4900])
      end

      it "protects existing customers when count increases from 3 to 5" do
        # Seller changes installment plan from 3 to 5 payments
        installment_plan.update!(number_of_installments: 5)

        # Existing snapshot remains unchanged
        snapshot.reload
        expect(snapshot.number_of_installments).to eq(3)

        # Live plan should be updated for new customers
        expect(installment_plan.reload.number_of_installments).to eq(5)

        # Existing customer still gets 3 installments (not extended to 5)
        payments = snapshot.calculate_installment_payment_price_cents
        expect(payments.length).to eq(3)
        expect(payments).to eq([4900, 4900, 4900])
      end
    end

  end
end
