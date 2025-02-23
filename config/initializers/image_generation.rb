Rails.application.configure do
  config.image_generation = ActiveSupport::OrderedOptions.new
  config.image_generation.provider = ENV.fetch('IMAGE_GENERATION_PROVIDER', 'fal').to_sym
  
  # Provider-specific configurations
  config.image_generation.providers = {
    fal: {
      api_key: ENV['FAL_API_KEY'],
      model: ENV.fetch('FAL_MODEL', 'fal-ai/recraft-v3')
    },
    dalle: {
      api_key: ENV['OPENAI_API_KEY'],
      model: ENV.fetch('DALLE_MODEL', 'dall-e-3')
    }
  }
end 