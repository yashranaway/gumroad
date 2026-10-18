# frozen_string_literal: true

require "spec_helper"

describe MailerHelper do
  describe "#from_email_address_name" do
    context "when name doesn't contain special characters" do
      it "returns the name" do
        expect(from_email_address_name("John The Creator")).to eq("John The Creator")
      end
    end

    context "when name contains colon character" do
      it "strips the colon and returns the cleaned name" do
        expect(from_email_address_name("John: The Creator")).to eq("John The Creator")
      end
    end
  end

  describe "#from_address_with_name" do
    it "leaves a name without RFC 5322 specials unquoted" do
      expect(from_address_with_name("Bob", "bob@example.com")).to eq("Bob <bob@example.com>")
    end

    it "quotes a name containing a comma" do
      expect(from_address_with_name("Smith, John", "bob@example.com")).to eq(%("Smith, John" <bob@example.com>))
    end

    it "quotes a name containing angle brackets" do
      expect(from_address_with_name("i27312TAG<b>x</b>", "bob@example.com")).to eq(%("i27312TAG<b>x</b>" <bob@example.com>))
    end

    it "falls back to Gumroad when the name has no usable value" do
      expect(from_address_with_name(nil, "bob@example.com")).to eq("Gumroad <bob@example.com>")
    end
  end
end
