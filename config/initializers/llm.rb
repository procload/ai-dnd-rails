# frozen_string_literal: true

Rails.application.configure do
  # Configure the LLM service
  config.llm = ActiveSupport::OrderedOptions.new
  
  # Use Anthropic in development, mock in test, and Anthropic in production
  default_provider = case Rails.env
                    when 'test'
                      :mock
                    else
                      :anthropic
                    end
  
  # Set the active provider
  config.llm.provider = (ENV['LLM_PROVIDER'] || default_provider).to_sym

  # Configure available providers
  config.llm.providers = {
    anthropic: {
      api_key: ENV['ANTHROPIC_API_KEY'],
      model: ENV['ANTHROPIC_MODEL'] || 'claude-3-5-sonnet-20241022',
      max_tokens: (ENV['ANTHROPIC_MAX_TOKENS'] || 4096).to_i,
      temperature: (ENV['ANTHROPIC_TEMPERATURE'] || 0.7).to_f
    },
    openai: {
      api_key: ENV['OPENAI_API_KEY'],
      model: ENV['OPENAI_MODEL'] || 'gpt-4-turbo-preview',
      max_tokens: (ENV['OPENAI_MAX_TOKENS'] || 4096).to_i,
      temperature: (ENV['OPENAI_TEMPERATURE'] || 0.7).to_f
    },
    mock: {
      # Mock provider doesn't need any configuration
    }
  }

  # Validate configuration in production
  if Rails.env.production?
    provider = config.llm.provider
    provider_config = config.llm.providers[provider]

    unless provider_config
      raise "Invalid LLM provider configured: #{provider}"
    end

    if provider != :mock && !provider_config[:api_key]
      raise "Missing API key for LLM provider: #{provider}"
    end
  end
end 