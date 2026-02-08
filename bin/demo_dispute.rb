ActiveRecord::Base.logger = nil
ActiveSupport::Deprecation.silenced = true rescue nil
Searchkick.disable_callbacks if defined?(Searchkick)
Elasticsearch::Model.client.transport.logger = nil rescue nil
Sidekiq.logger.level = Logger::FATAL rescue nil

puts "\n  PayPal Dispute Auto-Fighting Demo\n\n"

merchant_account = MerchantAccount.gumroad(PaypalChargeProcessor.charge_processor_id)

seller = User.create!(email: "demo-seller-#{SecureRandom.hex(4)}@example.com", password: "password123456")
permalink = "demo#{SecureRandom.alphanumeric(6).downcase.gsub(/[0-9]/, 'x')}"
product = Link.create!(name: "Ultimate Design Course", price_cents: 4900, user: seller, unique_permalink: permalink)

purchase = Purchase.new(
  link: product,
  seller: seller,
  charge_processor_id: PaypalChargeProcessor.charge_processor_id,
  stripe_transaction_id: "5TY482935W123456R",
  merchant_account: merchant_account,
  email: "john.buyer@example.com",
  full_name: "John Doe",
  ip_address: "203.0.113.42",
  card_type: CardType::PAYPAL,
  card_visual: "john.buyer@example.com",
  price_cents: 4900,
  total_transaction_cents: 4900,
  displayed_price_cents: 4900,
  purchase_state: "successful",
  succeeded_at: 3.days.ago,
  flow_of_funds: FlowOfFunds.build_simple_flow_of_funds(Currency::USD, 4900),
  country: "US"
)
purchase.save!(validate: false)

puts "1. Purchase created"
puts "   #{product.name} — $#{'%.2f' % (purchase.price_cents / 100.0)} via PayPal"
puts "   Buyer: #{purchase.full_name} (#{purchase.email})"
puts "   Capture ID: #{purchase.stripe_transaction_id}\n\n"

dispute = Dispute.create!(
  purchase: purchase,
  charge_processor_id: PaypalChargeProcessor.charge_processor_id,
  charge_processor_dispute_id: "PP-D-98765",
  reason: Dispute::REASON_PRODUCT_NOT_RECEIVED,
  event_created_at: Time.current,
  state: :formalized,
  formalized_at: Time.current
)

puts "2. Dispute opened (CUSTOMER_DISPUTE_CREATED webhook)"
puts "   ID: #{dispute.charge_processor_dispute_id}  Reason: #{dispute.reason}\n\n"

dispute_evidence = DisputeEvidence.create!(
  dispute: dispute,
  customer_name: purchase.full_name,
  customer_email: purchase.email,
  customer_purchase_ip: purchase.ip_address,
  billing_address: "123 Main St, San Francisco, CA 94102, US",
  product_description: "Digital course: #{product.name} - Online video course with downloadable resources",
  reason_for_winning: "Product was delivered digitally. Customer accessed course content multiple times since purchase.",
  purchased_at: purchase.created_at,
  seller_contacted_at: Time.current
)

puts "3. Evidence collected"
puts "   Customer: #{dispute_evidence.customer_name} (#{dispute_evidence.customer_email})"
puts "   IP: #{dispute_evidence.customer_purchase_ip}"
puts "   Auto-fight eligible: #{purchase.eligible_for_dispute_evidence?}\n\n"

processor = PaypalChargeProcessor.new
notes = processor.send(:build_structured_evidence_notes, dispute_evidence, dispute)
evidence_type = processor.send(:determine_evidence_type_for_dispute, dispute)

puts "4. Structured notes for PayPal (#{notes.length}/2000 chars, type: #{evidence_type})\n\n"
puts notes
puts "\n"

puts "5. Would submit via API"
puts "   POST /v1/customer/disputes/#{dispute.charge_processor_dispute_id}/provide-evidence"
puts "   FightDisputeJob.perform_async(#{dispute.id})\n\n"

# Cleanup
dispute_evidence.destroy!
dispute.destroy!
purchase.destroy!
product.destroy!
seller.destroy!
