# frozen_string_literal: true

class Exports::Audience::ProcessChunkWorker
  include Sidekiq::Job
  sidekiq_options retry: 5, queue: :low, lock: :until_executed

  def perform(chunk_id)
    @chunk = AudienceExportChunk.find(chunk_id)
    @export = @chunk.export

    process_chunk
    return if chunks_left_to_process?

    Exports::Audience::CompileChunksWorker.perform_async(@export.id)
  end

  private
    def process_chunk
      members = AudienceMember.where(id: @chunk.member_ids).select(:id, :email, :min_created_at)
      members_data = members.map { |m| [m.email, m.min_created_at.to_s] }

      @chunk.update!(
        members_data:,
        processed: true,
        revision: REVISION
      )
    end

    def chunks_left_to_process?
      return true if @export.chunks.where(processed: false).exists?
      return false if @export.chunks.where(processed: true, revision: REVISION).count == @export.chunks.count

      processed_with_old_revision = @export.chunks.where(processed: true).where.not(revision: REVISION).ids
      self.class.perform_bulk(processed_with_old_revision.map { |id| [id] })
      true
    end
end
