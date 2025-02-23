class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs for transient failures
  retry_on StandardError, wait: :exponentially_longer, attempts: 3 do |job, error|
    Rails.logger.error "Job #{job.class.name} (#{job.job_id}) failed permanently: #{error.message}"
  end

  around_perform do |job, block|
    track_job_count(job) { block.call }
  end

  private

  def track_job_count(job)
    user_id = current_user_id(job)
    return yield unless user_id

    begin
      UserJobCounter.increment(user_id)
      yield
    ensure
      UserJobCounter.decrement(user_id)
    end
  end

  def current_user_id(job)
    # Try to find a user_id in the job arguments
    job.arguments.find { |arg| arg.is_a?(Integer) }
  end
end
