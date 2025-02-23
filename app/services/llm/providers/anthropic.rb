# frozen_string_literal: true

require 'net/http'
require 'json'
require 'yaml'

module Llm
  module Providers
    class Anthropic < Base
      ANTHROPIC_API_URL = 'https://api.anthropic.com/v1/messages'
      ANTHROPIC_API_VERSION = '2023-06-01'
      MAX_RETRIES = 3
      RETRY_DELAY = 1 # Base delay in seconds
      RATE_LIMIT_REQUESTS = 50 # Requests per minute
      RATE_LIMIT_WINDOW = 60 # Window in seconds

      class RateLimiter
        def initialize(max_requests, window_seconds)
          @max_requests = max_requests
          @window_seconds = window_seconds
          @requests = []
        end

        def wait_if_needed
          now = Time.now
          # Remove old requests outside the window
          @requests.reject! { |time| time < now - @window_seconds }

          if @requests.size >= @max_requests
            sleep_time = @requests.first + @window_seconds - now
            sleep(sleep_time) if sleep_time > 0
            @requests.shift
          end

          @requests << now
        end
      end

      def initialize(config)
        super
        validate_config!(:api_key, :model)
        @rate_limiter = RateLimiter.new(RATE_LIMIT_REQUESTS, RATE_LIMIT_WINDOW)
      end

      def chat(messages:, system_prompt: nil)
        log_request(:chat, messages: messages, system_prompt: system_prompt)

        # Validate messages
        validate_messages!(messages)

        # Determine the request type from the last message
        last_message = messages.last
        request_type = determine_request_type(last_message['content'])

        # Get the appropriate schema for this request type
        schema = get_schema_for_request(request_type)

        # Use chat_with_schema for consistent handling
        chat_with_schema(
          messages: messages,
          system_prompt: system_prompt,
          schema: schema
        )
      rescue StandardError => e
        log_error(:chat, e)
        raise Llm::Service::ProviderError, "Anthropic API error: #{e.message}"
      end

      def chat_with_schema(messages:, system_prompt: nil, schema:, provider_config: nil)
        log_request(:chat_with_schema, messages: messages, system_prompt: system_prompt, schema: schema)

        # Validate inputs
        validate_messages!(messages)
        validate_schema!(schema)

        # Add schema to system message
        system_message = system_prompt || "You are a D&D character trait generator. Generate unique and fitting traits for the character."
        system_message += "\n\nYou must respond with a JSON object following this schema:\n#{schema.to_json}"
        system_message += "\n\nDo not include any explanations or text outside the JSON object."

        # Make the API request
        response = make_request(
          messages: messages,
          system_prompt: system_message
        )

        # Handle and validate the response
        result = handle_response(response)
        validate_response_against_schema!(result, schema)
        
        result
      rescue StandardError => e
        log_error(:chat_with_schema, e)
        raise Llm::Service::ProviderError, "Anthropic API error: #{e.message}"
      end

      def test_connection
        # Use a simple background request for testing
        begin
          Rails.logger.debug "[Anthropic] Testing connection with model: #{config[:model]}"
          chat(
            messages: [{
              'role' => 'user',
              'content' => 'Generate a test background'
            }]
          )
          true
        rescue StandardError => e
          Rails.logger.error "[Anthropic] Connection test failed: #{e.message}"
          Rails.logger.error "[Anthropic] Error backtrace: #{e.backtrace.take(5).join("\n")}"
          false
        end
      end

      private

      def make_request(messages:, system_prompt: nil)
        retries = 0
        begin
          @rate_limiter.wait_if_needed

          uri = URI(ANTHROPIC_API_URL)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true

          request = Net::HTTP::Post.new(uri)
          request['Content-Type'] = 'application/json'
          request['x-api-key'] = config[:api_key]
          request['anthropic-version'] = ANTHROPIC_API_VERSION

          # Log request headers for debugging
          Rails.logger.debug "[Anthropic] Request headers: #{request.to_hash.inspect}"

          # Prepare request body
          request_body = {
            model: config[:model],
            messages: messages,
            max_tokens: config[:max_tokens],
            temperature: config[:temperature],
            metadata: {
              user_id: 'dnd-rails-app'
            }
          }

          # Add system prompt if provided
          request_body[:system] = system_prompt if system_prompt

          request.body = request_body.compact.to_json

          # Log the request body for debugging
          Rails.logger.debug "[Anthropic] Request body: #{request.body}"

          response = http.request(request)

          # Log response details
          Rails.logger.debug "[Anthropic] Response status: #{response.code}"
          Rails.logger.debug "[Anthropic] Response headers: #{response.to_hash.inspect}"
          Rails.logger.debug "[Anthropic] Response body: #{response.body}" if response.body

          # Handle rate limiting with retries
          if response.is_a?(Net::HTTPTooManyRequests)
            retry_after = (response['retry-after']&.to_i || RETRY_DELAY)
            raise Llm::Service::RateLimitError.new("Rate limit exceeded. Retry after #{retry_after} seconds")
          end

          response
        rescue Llm::Service::RateLimitError, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
          retries += 1
          if retries <= MAX_RETRIES
            # Exponential backoff with jitter
            sleep_time = [RETRY_DELAY * (2 ** (retries - 1)) + rand, 30].min
            Rails.logger.warn "[Anthropic] Request failed (attempt #{retries}/#{MAX_RETRIES}): #{e.message}. Retrying in #{sleep_time} seconds..."
            sleep(sleep_time)
            retry
          else
            Rails.logger.error "[Anthropic] Request failed after #{MAX_RETRIES} retries: #{e.message}"
            raise Llm::Service::ProviderError, "Failed after #{MAX_RETRIES} retries: #{e.message}"
          end
        end
      end

      def validate_messages!(messages)
        raise Llm::Service::ProviderError, 'No messages provided' if messages.nil? || messages.empty?
        
        last_message = messages.last
        raise Llm::Service::ProviderError, 'Invalid message format' unless last_message.is_a?(Hash)
        raise Llm::Service::ProviderError, 'Missing message content' unless last_message['content'].is_a?(String)
        raise Llm::Service::ProviderError, 'Missing message role' unless last_message['role'].is_a?(String)
      end

      def determine_request_type(content)
        case content.downcase
        when /background/
          'character_background'
        when /equipment/
          'suggest_equipment'
        when /spells/
          'suggest_spells'
        else
          'character_background' # Default to background if unclear
        end
      end

      def get_schema_for_request(request_type)
        # Load the template for this request type
        template = YAML.load_file(
          Rails.root.join('config', 'prompts', 'default', "#{request_type}.yml")
        )
        
        # Extract and return the schema from the template
        template['schema'] || {
          type: 'object',
          required: ['background', 'personality_traits'],
          properties: {
            background: {
              type: 'string',
              description: 'A detailed background story for the character'
            },
            personality_traits: {
              type: 'array',
              description: 'List of personality traits that define the character',
              items: { type: 'string' },
              minItems: 2,
              maxItems: 4
            }
          }
        }
      end

      def handle_response(response)
        Rails.logger.debug "[Anthropic] Response status: #{response.code}"
        Rails.logger.debug "[Anthropic] Response headers: #{response.to_hash.inspect}"
        
        case response
        when Net::HTTPSuccess
          parse_successful_response(response.body)
        when Net::HTTPUnauthorized
          raise Llm::Service::ProviderError, 'Invalid API key'
        when Net::HTTPTooManyRequests
          raise Llm::Service::ProviderError, 'Rate limit exceeded'
        else
          error_body = JSON.parse(response.body) rescue nil
          error_message = error_body&.dig('error', 'message') || response.message
          Rails.logger.error "[Anthropic] Error response body: #{response.body}"
          raise Llm::Service::ProviderError, "HTTP #{response.code}: #{error_message}"
        end
      end

      def parse_successful_response(body)
        # Log the raw response body
        Rails.logger.debug "[Anthropic] Raw response body: #{body}"
        
        data = JSON.parse(body)
        Rails.logger.debug "[Anthropic] Parsed response data: #{data.inspect}"

        # Extract the message content
        message = if data['content'].is_a?(Array)
          data['content'].first&.dig('text')
        else
          data['content']
        end
        
        Rails.logger.debug "[Anthropic] Extracted message: #{message.inspect}"
        if message.nil?
          log_error(:chat, "No message text in response")
          raise Llm::Service::ProviderError, 'No message text in response from Anthropic'
        end

        # Try to extract JSON from the message
        # First, look for JSON-like content between triple backticks
        json_match = message.match(/```(?:json)?\s*(\{.+?\})\s*```/m)
        json_string = json_match ? json_match[1] : message

        # Clean up the JSON string
        json_string = json_string.strip
                                .gsub(/\A\s*\{/, '{') # Remove leading whitespace before {
                                .gsub(/\}\s*\z/, '}')  # Remove trailing whitespace after }
                                .gsub(/\n\s*/, '')     # Remove newlines and their surrounding whitespace

        Rails.logger.debug "[Anthropic] Cleaned JSON string: #{json_string.inspect}"

        begin
          JSON.parse(json_string)
        rescue JSON::ParserError => e
          log_error(:chat, "Failed to parse JSON response: #{e.message}")
          raise Llm::Service::ProviderError, 'Invalid JSON response from Anthropic'
        end
      end
    end
  end
end 