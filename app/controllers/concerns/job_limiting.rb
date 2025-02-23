module JobLimiting
  extend ActiveSupport::Concern

  private

  def check_job_limit!
    user_id = params[:user_id]
    return if UserJobCounter.can_enqueue?(user_id)

    respond_to do |format|
      format.html do
        flash[:alert] = "You have reached the maximum number of concurrent jobs (#{Rails.configuration.x.max_concurrent_jobs_per_user})"
        redirect_back(fallback_location: root_path)
      end
      format.turbo_stream do
        flash.now[:alert] = "You have reached the maximum number of concurrent jobs (#{Rails.configuration.x.max_concurrent_jobs_per_user})"
        render turbo_stream: turbo_stream.update("flash", partial: "shared/flash")
      end
      format.json do
        render json: { 
          error: "Job limit reached",
          message: "You have reached the maximum number of concurrent jobs (#{Rails.configuration.x.max_concurrent_jobs_per_user})"
        }, status: :unprocessable_entity
      end
    end
  end
end 