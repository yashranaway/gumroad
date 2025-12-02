# frozen_string_literal: true

require "spec_helper"

describe User::LowBalanceFraudCheck do
  before do
    @creator = create(:user)
    @purchase = create(:refunded_purchase, link: create(:product, user: @creator))
  end

  describe "#enable_refunds!" do
    before do
      @creator.refunds_disabled = true
    end

    it "enables refunds for the creator" do
      @creator.enable_refunds!

      expect(@creator.reload.refunds_disabled?).to eq(false)
    end


    it "is called when a creator is marked as compliant" do
      @creator.mark_compliant!(author_name: "test")

      expect(@creator.reload.refunds_disabled?).to eq(false)
    end
  end

  describe "#disable_refunds!" do
    before do
      @creator.refunds_disabled = false
    end

    it "disables refunds for the creator" do
      @creator.disable_refunds!

      expect(@creator.reload.refunds_disabled?).to eq(true)
    end
  end

  describe "#check_for_low_balance_and_probate" do
    context "when the unpaid balance is above threshold" do
      before do
        allow(@creator).to receive(:unpaid_balance_cents).and_return(-40_00)
      end

      it "doesn't probate the creator" do
        @creator.check_for_low_balance_and_probate(@purchase.id)

        expect(@creator.reload.on_probation?).to eq(false)
      end
    end

    context "when the unpaid balance is below threshold" do
      before do
        allow(@creator).to receive(:unpaid_balance_cents).and_return(-200_00)
      end

      context "when the creator is not on probation" do
        context "when the creator is not recently probated for low balance" do
          it "probates the creator" do
            expect do
              @creator.check_for_low_balance_and_probate(@purchase.id)
            end.to have_enqueued_mail(AdminMailer, :low_balance_notify).with(@creator.id, @purchase.id)

            expect(@creator.reload.on_probation?).to eq(true)
            expect(@creator.comments.last.content).to eq("Probated (payouts suspended) automatically on #{Time.current.to_fs(:formatted_date_full_month)} because of suspicious refund activity")
          end
        end

        context "when the creator is recently probated" do
          context "when creator was probated before LOW_BALANCE_PROBATION_WAIT_TIME" do
            before do
              @creator.send(:disable_refunds_and_put_on_probation!)
              comment = @creator.comments.with_type_on_probation.order(:created_at).last
              comment.update_attribute(:created_at, 3.months.ago)
              @creator.mark_compliant(author_name: "test")
            end

            it "probates the creator" do
              expect do
                @creator.check_for_low_balance_and_probate(@purchase.id)
              end.to have_enqueued_mail(AdminMailer, :low_balance_notify).with(@creator.id, @purchase.id)

              expect(@creator.reload.on_probation?).to eq(true)
              expect(@creator.comments.last.content).to eq("Probated (payouts suspended) automatically on #{Time.current.to_fs(:formatted_date_full_month)} because of suspicious refund activity")
            end
          end

          context "when creator was probated after LOW_BALANCE_PROBATION_WAIT_TIME" do
            before do
              @creator.send(:disable_refunds_and_put_on_probation!)
              comment = @creator.comments.with_type_on_probation.order(:created_at).last
              comment.update_attribute(:created_at, 1.months.ago)
              @creator.mark_compliant(author_name: "test")
            end

            it "doesn't probate the creator" do
              expect do
                @creator.check_for_low_balance_and_probate(@purchase.id)
              end.to have_enqueued_mail(AdminMailer, :low_balance_notify).with(@creator.id, @purchase.id)

              expect(@creator.reload.on_probation?).to eq(false)
            end
          end
        end
      end
    end
  end

  describe "#check_for_balance_recovery_and_mark_compliant" do
    context "when the user is on probation" do
      context "when the user was probated by LowBalanceFraudCheck" do
        context "when the user was previously compliant" do
          before do
            @creator.update!(user_risk_state: "compliant")
            @creator.send(:disable_refunds_and_put_on_probation!)
          end

          context "when the unpaid balance is above $100" do
            before do
              allow(@creator).to receive(:unpaid_balance_cents).and_return(150_00)
            end

            it "restores the creator to compliant state" do
              @creator.check_for_balance_recovery_and_mark_compliant

              expect(@creator.reload.compliant?).to eq(true)
              expect(@creator.comments.last.content).to include("Automatically restored to compliant state")
              expect(@creator.comments.last.content).to include("balance recovered above $100")
              expect(@creator.comments.last.author_name).to eq("LowBalanceFraudCheck")
            end

            it "enables refunds for the creator" do
              @creator.check_for_balance_recovery_and_mark_compliant

              expect(@creator.reload.refunds_disabled?).to eq(false)
            end
          end
        end

        context "when the user was previously not_reviewed" do
          before do
            @creator.update!(user_risk_state: "not_reviewed")
            @creator.send(:disable_refunds_and_put_on_probation!)
          end

          context "when the unpaid balance is above $100" do
            before do
              allow(@creator).to receive(:unpaid_balance_cents).and_return(150_00)
            end

            it "restores the creator to not_reviewed state" do
              @creator.check_for_balance_recovery_and_mark_compliant

              expect(@creator.reload.not_reviewed?).to eq(true)
              expect(@creator.comments.last.content).to include("Automatically restored to not_reviewed state")
              expect(@creator.comments.last.content).to include("balance recovered above $100")
              expect(@creator.comments.last.author_name).to eq("LowBalanceFraudCheck")
            end

            it "enables refunds for the creator" do
              @creator.check_for_balance_recovery_and_mark_compliant

              expect(@creator.reload.refunds_disabled?).to eq(false)
            end
          end
        end

        context "when the user was previously flagged_for_fraud" do
          before do
            @creator.update!(user_risk_state: "flagged_for_fraud")
            @creator.send(:disable_refunds_and_put_on_probation!)
          end

          context "when the unpaid balance is above $100" do
            before do
              allow(@creator).to receive(:unpaid_balance_cents).and_return(150_00)
            end

            it "restores the creator to compliant state (not flagged)" do
              @creator.check_for_balance_recovery_and_mark_compliant

              expect(@creator.reload.compliant?).to eq(true)
            end

            it "enables refunds for the creator" do
              @creator.check_for_balance_recovery_and_mark_compliant

              expect(@creator.reload.refunds_disabled?).to eq(false)
            end
          end
        end

        context "when the unpaid balance is exactly $100" do
          before do
            @creator.update!(user_risk_state: "compliant")
            @creator.send(:disable_refunds_and_put_on_probation!)
            allow(@creator).to receive(:unpaid_balance_cents).and_return(100_00)
          end

          it "does not restore the creator" do
            @creator.check_for_balance_recovery_and_mark_compliant

            expect(@creator.reload.on_probation?).to eq(true)
          end
        end

        context "when the unpaid balance is below $100" do
          before do
            @creator.update!(user_risk_state: "compliant")
            @creator.send(:disable_refunds_and_put_on_probation!)
            allow(@creator).to receive(:unpaid_balance_cents).and_return(50_00)
          end

          it "does not restore the creator" do
            @creator.check_for_balance_recovery_and_mark_compliant

            expect(@creator.reload.on_probation?).to eq(true)
          end
        end

        context "when previous state cannot be found in PaperTrail versions" do
          before do
            @creator.update!(user_risk_state: "on_probation")
            @creator.comments.create!(
              content: "Manual probation",
              comment_type: Comment::COMMENT_TYPE_ON_PROBATION,
              author_name: "LowBalanceFraudCheck"
            )
            @creator.versions.destroy_all
            allow(@creator).to receive(:unpaid_balance_cents).and_return(150_00)
          end

          it "does not restore the creator" do
            @creator.check_for_balance_recovery_and_mark_compliant

            expect(@creator.reload.on_probation?).to eq(true)
          end
        end
      end

      context "when the user was not probated by LowBalanceFraudCheck" do
        before do
          @creator.update!(user_risk_state: "on_probation")
          @creator.comments.create!(
            content: "Manual probation",
            comment_type: Comment::COMMENT_TYPE_ON_PROBATION,
            author_name: "admin"
          )
          allow(@creator).to receive(:unpaid_balance_cents).and_return(150_00)
        end

        it "does not restore the creator" do
          @creator.check_for_balance_recovery_and_mark_compliant

          expect(@creator.reload.on_probation?).to eq(true)
        end
      end
    end

    context "when the user is not on probation" do
      before do
        allow(@creator).to receive(:unpaid_balance_cents).and_return(150_00)
      end

      it "does not change the creator state" do
        expect { @creator.check_for_balance_recovery_and_mark_compliant }.not_to change { @creator.reload.user_risk_state }
      end
    end
  end

  describe "#probated_by_low_balance_fraud_check?" do
    context "when user was probated by LowBalanceFraudCheck" do
      before do
        @creator.update!(user_risk_state: "compliant")
        @creator.send(:disable_refunds_and_put_on_probation!)
      end

      it "returns true" do
        expect(@creator.send(:probated_by_low_balance_fraud_check?)).to eq(true)
      end
    end

    context "when user was probated by admin" do
      before do
        @creator.update!(user_risk_state: "on_probation")
        @creator.comments.create!(
          content: "Manual probation",
          comment_type: Comment::COMMENT_TYPE_ON_PROBATION,
          author_name: "admin"
        )
      end

      it "returns false" do
        expect(@creator.send(:probated_by_low_balance_fraud_check?)).to eq(false)
      end
    end
  end
end
