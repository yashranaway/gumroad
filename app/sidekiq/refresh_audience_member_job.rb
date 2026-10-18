# frozen_string_literal: true

# Converges one buyer's audience_members row out of band. Purchase changes schedule this
# instead of writing the projection inline (see Purchase::AudienceMember); follower and
# affiliate callbacks fall back to it when their incremental update hits a LockWaitTimeout.
# refresh! rebuilds from live purchase/follower/affiliate state, so running it once the
# contending writers finish is correct regardless of which update lost.
#
# lock: :until_executing (not :until_executed) so a purchase that commits while a refresh
# is already running can enqueue a follow-up. :until_executed + on_conflict: :replace
# dropped that follow-up and left the projection stale. refresh! uses with_lock so
# the row lock holds through the source reads and save.
class RefreshAudienceMemberJob
  include Sidekiq::Job
  sidekiq_options retry: 5, queue: :low, lock: :until_executing

  # Call sites enqueue from after_commit on a committed write (see Purchase::AudienceMember),
  # so a Redis outage must not turn that request into a 500. The projection is derived data:
  # refresh! rebuilds it from live state, and the next change to the same member re-schedules it.
  def self.enqueue(email, seller_id)
    perform_async(email, seller_id)
  rescue *REDIS_TRANSPORT_ERRORS => e
    Rails.logger.warn("Audience member refresh enqueue skipped for seller #{seller_id}: #{e.class}")
  end

  def perform(email, seller_id)
    AudienceMember.find_or_initialize_by(email:, seller_id:).refresh!
  end
end
