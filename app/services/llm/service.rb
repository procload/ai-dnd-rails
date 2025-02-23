# frozen_string_literal: true

require_relative '../image_generation/errors'

module Llm
  class Service
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class ProviderError < Error; end
    class RateLimitError < ProviderError; end

    MAX_RETRIES = 3
    RETRY_DELAY = 1 # seconds

    attr_reader :provider

    class << self
      def chat(messages:, system_prompt: nil)
        new.chat(
          messages: messages,
          system_prompt: system_prompt
        )
      end

      def chat_with_schema(messages:, system_prompt: nil, schema:)
        new.chat_with_schema(
          messages: messages,
          system_prompt: system_prompt,
          schema: schema
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
      
      with_retries do
        @provider.chat(
          messages: messages,
          system_prompt: system_prompt
        )
      end
    rescue StandardError => e
      Rails.logger.error "[Llm::Service] Error in chat: #{e.class} - #{e.message}"
      raise ProviderError, "Failed to process chat request: #{e.message}"
    end

    def chat_with_schema(messages:, system_prompt: nil, schema:)
      Rails.logger.info "[Llm::Service] Sending schema-validated chat request with #{messages.length} messages"
      Rails.logger.debug "[Llm::Service] Using schema: #{schema.inspect}"

      with_retries do
        @provider.chat_with_schema(
          messages: messages,
          system_prompt: system_prompt,
          schema: schema
        )
      end
    rescue StandardError => e
      Rails.logger.error "[Llm::Service] Error in chat_with_schema: #{e.class} - #{e.message}"
      raise ProviderError, "Failed to process structured chat request: #{e.message}"
    end

    def test_connection
      with_retries do
        chat(messages: [{ role: 'user', content: 'test' }])
        true
      end
    rescue StandardError => e
      Rails.logger.error "[Llm::Service] Connection test failed: #{e.class} - #{e.message}"
      false
    end

    private

    def with_retries
      retries = 0
      begin
        yield
      rescue RateLimitError => e
        retries += 1
        if retries <= MAX_RETRIES
          Rails.logger.warn "[Llm::Service] Rate limited, attempt #{retries}/#{MAX_RETRIES}. Retrying in #{RETRY_DELAY} seconds..."
          sleep RETRY_DELAY
          retry
        else
          Rails.logger.error "[Llm::Service] Max retries (#{MAX_RETRIES}) exceeded"
          raise
        end
      rescue StandardError => e
        retries += 1
        if retries <= MAX_RETRIES
          Rails.logger.warn "[Llm::Service] Error occurred, attempt #{retries}/#{MAX_RETRIES}. Retrying in #{RETRY_DELAY} seconds..."
          sleep RETRY_DELAY
          retry
        else
          Rails.logger.error "[Llm::Service] Max retries (#{MAX_RETRIES}) exceeded"
          raise
        end
      end
    end
  end
end 