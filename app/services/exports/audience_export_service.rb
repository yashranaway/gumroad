# frozen_string_literal: true

require "csv"

class Exports::AudienceExportService
  FIELDS = ["Subscriber Email", "Subscribed Time"].freeze
  SYNCHRONOUS_EXPORT_THRESHOLD = 10_000

  def initialize(user, options = {})
    @user = user
    @options = options.with_indifferent_access
    timestamp = Time.current.to_fs(:db).gsub(/ |:/, "-")
    @filename = "Subscribers-#{@user.username}_#{timestamp}.csv"

    validate_options!
  end

  attr_reader :filename, :tempfile

  def self.export(seller:, recipient:, options:)
    options = options.with_indifferent_access
    count = build_count_query(seller, options)

    if count <= SYNCHRONOUS_EXPORT_THRESHOLD
      new(seller, options).perform
    else
      export = AudienceExport.create!(seller:, recipient:, options: options.to_h)
      Exports::Audience::CreateAndEnqueueChunksWorker.perform_async(export.id)
      false
    end
  end

  def self.compile(members_data_enumerator)
    tempfile = Tempfile.new(["Subscribers", ".csv"], encoding: "UTF-8")

    CSV.open(tempfile, "wb", headers: FIELDS, write_headers: true) do |csv|
      members_data_enumerator.each do |email, timestamp|
        csv << [email, timestamp]
      end
    end

    tempfile.rewind
    tempfile
  end

  def perform
    @tempfile = Tempfile.new(["Subscribers", ".csv"], encoding: "UTF-8")

    CSV.open(@tempfile, "wb", headers: FIELDS, write_headers: true) do |csv|
      query = self.class.build_query(@user, @options)

      query.order(:min_created_at).find_each do |member|
        csv << [member.email, member.min_created_at]
      end
    end

    @tempfile.rewind

    self
  end

  def self.build_query(user, options)
    options = options.with_indifferent_access
    query = user.audience_members.select(:id, :email, :min_created_at)

    conditions = []
    conditions << "follower = true" if options[:followers]
    conditions << "customer = true" if options[:customers]
    conditions << "affiliate = true" if options[:affiliates]

    return query.none if conditions.empty?

    query.where(conditions.join(" OR "))
  end

  def self.build_count_query(user, options)
    options = options.with_indifferent_access
    query = user.audience_members

    conditions = []
    conditions << "follower = true" if options[:followers]
    conditions << "customer = true" if options[:customers]
    conditions << "affiliate = true" if options[:affiliates]

    return 0 if conditions.empty?

    query.where(conditions.join(" OR ")).count
  end

  private
    def validate_options!
      unless @options[:followers] || @options[:customers] || @options[:affiliates]
        raise ArgumentError, "At least one audience type (followers, customers, or affiliates) must be selected"
      end
    end
end
