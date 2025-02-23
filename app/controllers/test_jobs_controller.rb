class TestJobsController < ApplicationController
  include JobLimiting

  skip_before_action :verify_authenticity_token, only: [:hello_world, :test_concurrent]
  before_action :check_job_limit!, only: [:test_concurrent]
  
  def index
    # Simple view to test our jobs
  end

  def hello_world
    HelloWorldJob.perform_later
    
    respond_to do |format|
      format.html { redirect_to test_jobs_path, notice: "HelloWorldJob enqueued successfully!" }
      format.json { render json: { message: "HelloWorldJob enqueued" } }
      format.text { render plain: "HelloWorldJob enqueued" }
    end
  end

  def test_concurrent
    TestConcurrentJob.perform_later(params[:user_id])
    
    respond_to do |format|
      format.html { redirect_to test_jobs_path, notice: "TestConcurrentJob enqueued for user #{params[:user_id]}" }
      format.json { render json: { message: "TestConcurrentJob enqueued for user #{params[:user_id]}" } }
    end
  end
end 