# frozen_string_literal: true

module Llm
  class Service
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class ProviderError < Error; end
    class RateLimitError < ProviderError; end

    attr_reader :provider

    class << self
      def chat(messages:, system_prompt: nil)
        new.chat(
          messages: messages,
          system_prompt: system_prompt
        )
      end

      def test_connection
        new.test_connection
      end
    end

    def initialize
      @provider = Llm::Factory.create_provider
    end

    def chat(messages:, system_prompt: nil)
      Rails.logger.info "[Llm::Service] Sending chat request with #{messages.length} messages"
      
      @provider.chat(
        messages: messages,
        system_prompt: system_prompt
      )
    rescue StandardError => e
      Rails.logger.error "[Llm::Service] Error in chat: #{e.class} - #{e.message}"
      raise ProviderError, "Failed to process chat request: #{e.message}"
    end

    def test_connection
      @provider.test_connection
    rescue StandardError => e
      Rails.logger.error "[Llm::Service] Connection test failed: #{e.class} - #{e.message}"
      raise ProviderError, "Connection test failed: #{e.message}"
    end
  end
end 