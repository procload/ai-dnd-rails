# frozen_string_literal: true

module Llm
  module Providers
    class Base
      attr_reader :config

      def initialize(config)
        @config = config
      end

      def chat(messages:, system_prompt: nil)
        raise NotImplementedError, "#{self.class} must implement #chat"
      end

      def test_connection
        raise NotImplementedError, "#{self.class} must implement #test_connection"
      end

      protected

      def validate_config!(*required_keys)
        missing_keys = required_keys.select { |key| config[key].nil? }
        return if missing_keys.empty?

        raise Llm::Service::ConfigurationError,
              "Missing required configuration keys: #{missing_keys.join(', ')}"
      end

      def log_request(method, **params)
        Rails.logger.info "[#{self.class.name}] #{method} request: #{params.inspect}"
      end

      def log_response(method, response)
        Rails.logger.info "[#{self.class.name}] #{method} response: #{response.inspect}"
      end

      def log_error(method, error)
        error_message = error.is_a?(Exception) ? "#{error.class} - #{error.message}" : error.to_s
        Rails.logger.error "[#{self.class.name}] #{method} error: #{error_message}"
      end
    end
  end
end 