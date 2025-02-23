Rails.application.config.solid_queue.setup do |config|
  config.polling_interval = 1.second
  config.dispatch_interval = 0.5.seconds
  
  # Reduce connection pool usage
  config.connection_pool_size = 5
  
  # Development configuration
  if Rails.env.development?
    config.concurrency = 1
    config.process_jobs_async = true  # Enable async job processing
  end

  # Configure logger to use Rails logger
  config.logger = Rails.logger
  
  # Enable ActiveSupport::TaggedLogging
  if !Rails.logger.is_a?(ActiveSupport::TaggedLogging)
    config.logger = ActiveSupport::TaggedLogging.new(Rails.logger)
  end
end 