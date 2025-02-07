# frozen_string_literal: true

require 'net/http'
require 'json'
require 'yaml'

module Llm
  module Providers
    class Openai < Base
      OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions'
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

        # Prepare the messages array with system prompt
        chat_messages = []
        chat_messages << { 'role' => 'system', 'content' => system_prompt } if system_prompt
        chat_messages.concat(messages)

        # Make the API request
        response = make_request(
          messages: chat_messages,
          schema: schema,
          request_type: request_type
        )
        handle_response(response)
      rescue StandardError => e
        log_error(:chat, e)
        raise Llm::Service::ProviderError, "OpenAI API error: #{e.message}"
      end

      def test_connection
        # Use a simple background request for testing
        chat(
          messages: [{
            'role' => 'user',
            'content' => 'Generate a test background'
          }]
        )
        true
      rescue StandardError => e
        log_error(:test_connection, e)
        false
      end

      private

      def make_request(messages:, schema:, request_type:)
        retries = 0
        begin
          @rate_limiter.wait_if_needed

          uri = URI(OPENAI_API_URL)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true

          request = Net::HTTP::Post.new(uri)
          request['Content-Type'] = 'application/json'
          request['Authorization'] = "Bearer #{config[:api_key]}"

          # Construct the system message to include the schema and formatting instructions
          system_message = messages.find { |m| m['role'] == 'system' }&.dig('content')
          system_message = [
            system_message,
            "Please provide your response in JSON format according to this schema:",
            schema.to_json,
            "Your response should be valid JSON that matches this schema exactly."
          ].compact.join("\n\n")

          # Remove system message from messages array since it's handled separately
          messages = messages.reject { |m| m['role'] == 'system' }

          request.body = {
            model: config[:model],
            messages: [
              { role: 'system', content: system_message },
              *messages
            ],
            response_format: { type: 'json_object' },
            max_tokens: config[:max_tokens],
            temperature: config[:temperature]
          }.compact.to_json

          response = http.request(request)

          # Handle rate limiting with retries
          if response.is_a?(Net::HTTPTooManyRequests)
            retry_after = (response['retry-after']&.to_i || RETRY_DELAY)
            raise Llm::Service::RateLimitError.new("Rate limit exceeded. Retry after #{retry_after} seconds")
          end

          response
        rescue Llm::Service::RateLimitError, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
          retries += 1
          if retries <= MAX_RETRIES
            sleep_time = [RETRY_DELAY * (2 ** (retries - 1)) + rand, 30].min
            Rails.logger.warn "[OpenAI] Request failed (attempt #{retries}/#{MAX_RETRIES}): #{e.message}. Retrying in #{sleep_time} seconds..."
            sleep(sleep_time)
            retry
          else
            Rails.logger.error "[OpenAI] Request failed after #{MAX_RETRIES} retries: #{e.message}"
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
        Rails.logger.debug "[OpenAI] Response status: #{response.code}"
        Rails.logger.debug "[OpenAI] Response headers: #{response.to_hash.inspect}"
        
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
          Rails.logger.error "[OpenAI] Error response body: #{response.body}"
          raise Llm::Service::ProviderError, "HTTP #{response.code}: #{error_message}"
        end
      end

      def parse_successful_response(body)
        # Log the raw response body
        Rails.logger.debug "[OpenAI] Raw response body: #{body}"
        
        data = JSON.parse(body)
        Rails.logger.debug "[OpenAI] Parsed response data: #{data.inspect}"
        
        # Extract the message content
        # Handle empty choices array
        if data['choices'].nil? || data['choices'].empty?
          log_error(:chat, "Empty response choices")
          raise Llm::Service::ProviderError, 'Empty response from OpenAI'
        end
        
        # The response should contain a 'content' field with the assistant's message
        message = data['choices'].first&.dig('message', 'content')
        
        Rails.logger.debug "[OpenAI] Extracted message: #{message.inspect}"
        if message.nil?
          log_error(:chat, "No message content in response")
          raise Llm::Service::ProviderError, 'No message content in response from OpenAI'
        end

        begin
          # With response_format: { type: 'json_object' }, the content should be valid JSON
          result = JSON.parse(message)
          log_response(:chat, result)
          result
        rescue JSON::ParserError => e
          log_error(:chat, "Failed to parse JSON response: #{e.message}")
          log_error(:chat, "Response was: #{message}")
          raise Llm::Service::ProviderError, 'Invalid JSON response from OpenAI'
        end
      end
    end
  end
end 