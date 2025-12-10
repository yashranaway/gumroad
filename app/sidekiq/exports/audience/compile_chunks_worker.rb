# frozen_string_literal: true

class Exports::Audience::CompileChunksWorker
  include Sidekiq::Job
  sidekiq_options retry: 5, queue: :low, lock: :until_executed

  def perform(export_id)
    @export = AudienceExport.find(export_id)

    tempfile = generate_compiled_tempfile
    filename = generate_filename

    ContactingCreatorMailer.subscribers_data(
      recipient: @export.recipient,
      tempfile:,
      filename:,
    ).deliver_now

    @export.chunks.in_batches(of: 1).delete_all
    @export.destroy!
  end

  private
    def generate_compiled_tempfile
      members_data_enumerator = Enumerator.new do |yielder|
        @export.chunks.select(:id, :members_data).find_each(batch_size: 1) do |chunk|
          chunk.members_data.each do |data|
            yielder << data
          end
        end
      end

      Exports::AudienceExportService.compile(members_data_enumerator)
    end

    def generate_filename
      timestamp = Time.current.to_fs(:db).gsub(/ |:/, "-")
      "Subscribers-#{@export.seller.username}_#{timestamp}.csv"
    end
end
