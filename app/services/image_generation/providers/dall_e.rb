module ImageGeneration
  module Providers
    class DallE < Base
      API_ENDPOINT = 'https://api.openai.com/v1/images/generations'.freeze
      DEFAULT_MODEL = 'dall-e-3'
      VALID_SIZES = ['1024x1024', '1024x1792', '1792x1024'].freeze
      VALID_QUALITIES = ['standard', 'hd'].freeze
      VALID_STYLES = ['vivid', 'natural'].freeze

      def initialize(config)
        super
        Rails.logger.debug "[DALL-E] Initializing with config: #{config.except(:api_key).inspect}"
        validate_config!(:api_key)
        @config = default_config.merge(config)
        Rails.logger.debug "[DALL-E] Final config (excluding api_key): #{@config.except(:api_key).inspect}"
      end

      def generate_image(prompt)
        Rails.logger.info "[DALL-E] Generating image with config: #{config.except(:api_key)}"
        
        with_retries do
          response = make_request(prompt)
          process_response(response)
        end
      end

      private

      def default_config
        {
          model: DEFAULT_MODEL,
          size: '1024x1024',
          quality: 'standard',
          style: 'vivid',
          response_format: 'url'
        }
      end

      def make_request(prompt)
        uri = URI(API_ENDPOINT)
        request = Net::HTTP::Post.new(uri)
        request['Authorization'] = "Bearer #{config[:api_key]}"
        request['Content-Type'] = 'application/json'
        
        body = {
          model: config[:model],
          prompt: prompt,
          n: 1,
          quality: config[:quality],
          response_format: config[:response_format],
          size: config[:size],
          style: config[:style]
        }

        Rails.logger.info "[DALL-E] Making request with params: #{body.except(:prompt)}"
        Rails.logger.info "[DALL-E] Prompt length: #{prompt.length} characters"
        
        request.body = body.to_json

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        handle_response(response)
      end

      def handle_response(response)
        case response
        when Net::HTTPSuccess
          JSON.parse(response.body)
        when Net::HTTPUnauthorized
          raise ImageGeneration::ConfigurationError, "Invalid API key"
        when Net::HTTPTooManyRequests
          raise ImageGeneration::ProviderError, "Rate limit exceeded"
        else
          error_body = JSON.parse(response.body) rescue { error: { message: response.message } }
          raise ImageGeneration::ProviderError, "API error: #{error_body['error']['message']}"
        end
      end

      def process_response(response)
        return { error: response['error'] } if response['error']

        {
          url: response.dig('data', 0, 'url'),
          model: config[:model],
          created: Time.current,
          provider: 'dall-e',
          size: config[:size],
          quality: config[:quality],
          style: config[:style],
          revised_prompt: response.dig('data', 0, 'revised_prompt')
        }
      end

      def validate_config!(*)
        super
        Rails.logger.debug "[DALL-E] Validating configuration"
        
        if config[:size] && !VALID_SIZES.include?(config[:size])
          error_msg = "Invalid size. Must be one of: #{VALID_SIZES.join(', ')}"
          Rails.logger.error "[DALL-E] #{error_msg}"
          raise ImageGeneration::ConfigurationError, error_msg
        end

        if config[:quality] && !VALID_QUALITIES.include?(config[:quality])
          error_msg = "Invalid quality. Must be one of: #{VALID_QUALITIES.join(', ')}"
          Rails.logger.error "[DALL-E] #{error_msg}"
          raise ImageGeneration::ConfigurationError, error_msg
        end

        if config[:style] && !VALID_STYLES.include?(config[:style])
          error_msg = "Invalid style. Must be one of: #{VALID_STYLES.join(', ')}"
          Rails.logger.error "[DALL-E] #{error_msg}"
          raise ImageGeneration::ConfigurationError, error_msg
        end
        
        Rails.logger.debug "[DALL-E] Configuration validation passed"
      end
    end
  end
end 