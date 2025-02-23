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

      def chat_with_schema(messages:, system_prompt: nil, schema:, provider_config: nil)
        raise NotImplementedError, "#{self.class} must implement #chat_with_schema"
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

      def validate_schema!(schema)
        # Validate schema structure
        unless schema.is_a?(Hash) && schema['type'] == 'object'
          raise Llm::Service::ProviderError, "Schema must be an object type"
        end

        unless schema['properties'].is_a?(Hash)
          raise Llm::Service::ProviderError, "Schema must define properties"
        end

        unless schema['required'].is_a?(Array)
          raise Llm::Service::ProviderError, "Schema must specify required fields"
        end

        # Validate that all required fields exist in properties
        missing_properties = schema['required'] - schema['properties'].keys
        unless missing_properties.empty?
          raise Llm::Service::ProviderError, "Required fields missing from properties: #{missing_properties.join(', ')}"
        end

        # Validate array properties have minItems/maxItems if specified
        schema['properties'].each do |key, property|
          next unless property['type'] == 'array'
          
          if property['minItems'] && !property['minItems'].is_a?(Integer)
            raise Llm::Service::ProviderError, "minItems must be an integer for property: #{key}"
          end

          if property['maxItems'] && !property['maxItems'].is_a?(Integer)
            raise Llm::Service::ProviderError, "maxItems must be an integer for property: #{key}"
          end

          if property['minItems'] && property['maxItems'] && property['minItems'] > property['maxItems']
            raise Llm::Service::ProviderError, "minItems cannot be greater than maxItems for property: #{key}"
          end
        end
      end

      def validate_response_against_schema!(response, schema)
        # Validate required fields if specified
        if schema['required'].is_a?(Array)
          schema['required'].each do |field|
            unless response.key?(field)
              raise Llm::Service::ProviderError, "Response missing required field: #{field}"
            end
          end
        end

        # Validate field types and constraints
        schema['properties']&.each do |field, property|
          next unless response.key?(field)
          value = response[field]

          case property['type']
          when 'array'
            validate_array_field!(field, value, property)
          when 'string'
            validate_string_field!(field, value, property)
          when 'object'
            validate_object_field!(field, value, property)
          end
        end
      end

      def validate_array_field!(field, value, property)
        unless value.is_a?(Array)
          raise Llm::Service::ProviderError, "Field #{field} must be an array"
        end

        if property['minItems'] && value.length < property['minItems']
          raise Llm::Service::ProviderError, "Field #{field} must have at least #{property['minItems']} items"
        end

        if property['maxItems'] && value.length > property['maxItems']
          raise Llm::Service::ProviderError, "Field #{field} must have at most #{property['maxItems']} items"
        end

        # Validate array items if item schema is provided
        if property['items']
          value.each_with_index do |item, index|
            validate_response_against_schema!(
              item,
              { 'type' => 'object', 'properties' => property['items']['properties'], 'required' => property['items']['required'] }
            )
          end
        end
      end

      def validate_string_field!(field, value, property)
        unless value.is_a?(String)
          raise Llm::Service::ProviderError, "Field #{field} must be a string"
        end

        if property['enum'] && !property['enum'].include?(value)
          raise Llm::Service::ProviderError, "Field #{field} must be one of: #{property['enum'].join(', ')}"
        end
      end

      def validate_object_field!(field, value, property)
        unless value.is_a?(Hash)
          raise Llm::Service::ProviderError, "Field #{field} must be an object"
        end

        if property['properties']
          validate_response_against_schema!(
            value,
            { 'type' => 'object', 'properties' => property['properties'], 'required' => property['required'] }
          )
        end
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