class HelloWorldJob < ApplicationJob
  queue_as :default

  def perform(*args)
    Rails.logger.info "Hello World from Solid Queue!"
  end
end 