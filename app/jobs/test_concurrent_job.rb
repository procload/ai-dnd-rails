class TestConcurrentJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    Rails.logger.info "Starting job for user #{user_id}"
    sleep 2 # Simulate some work
    Rails.logger.info "Completed job for user #{user_id}"
  end
end 