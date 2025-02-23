class UserJobCounter
  # Use Concurrent::Map for thread-safe operations
  @@job_counts = Concurrent::Map.new { |h, k| h[k] = 0 }

  class << self
    def increment(user_id)
      @@job_counts.compute(user_id) { |_k, v| v + 1 }
    end

    def decrement(user_id)
      @@job_counts.compute(user_id) { |_k, v| [v - 1, 0].max }
    end

    def count_for(user_id)
      @@job_counts[user_id] || 0
    end

    def can_enqueue?(user_id)
      # Get the max jobs limit, defaulting to 10 if not configured
      max_jobs = begin
        value = Rails.application.config.x.max_concurrent_jobs_per_user
        # Convert to integer, handling both numeric and hash-like objects
        case value
        when Integer
          value
        when Hash, ActiveSupport::OrderedOptions
          value.to_h.fetch(:value, 10)
        else
          value.to_i.nonzero? || 10
        end
      rescue StandardError => e
        Rails.logger.warn "Failed to get max_concurrent_jobs_per_user config: #{e.message}. Using default of 10."
        10
      end

      current_count = count_for(user_id)
      Rails.logger.debug "Checking job limit for user #{user_id}: current=#{current_count}, max=#{max_jobs}"
      
      current_count < max_jobs
    end

    # For testing and cleanup
    def reset!
      @@job_counts.clear
    end
  end
end 