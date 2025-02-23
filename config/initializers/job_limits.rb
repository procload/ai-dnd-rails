# Set the maximum number of concurrent jobs per user
Rails.application.config.x.max_concurrent_jobs_per_user = 10

# Log that the configuration was loaded
Rails.logger.info "Job limits initialized: max_concurrent_jobs_per_user = #{Rails.application.config.x.max_concurrent_jobs_per_user.inspect}" 