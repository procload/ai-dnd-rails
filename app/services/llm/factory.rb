# frozen_string_literal: true

module Llm
  class Factory
    class << self
      def create_provider
        provider_name = Rails.configuration.llm.provider
        config = Rails.configuration.llm.providers[provider_name]
        
        provider_class = case provider_name.to_sym
        when :anthropic
          Llm::Providers::Anthropic
        when :openai
          Llm::Providers::Openai
        when :mock
          Llm::Providers::Mock
        else
          raise Llm::Service::ConfigurationError, "Unknown provider: #{provider_name}"
        end

        provider_class.new(config)
      rescue StandardError => e
        Rails.logger.error "[Llm::Factory] Failed to create provider: #{e.class} - #{e.message}"
        raise Llm::Service::ConfigurationError, "Failed to initialize provider: #{e.message}"
      end
    end
  end
end 