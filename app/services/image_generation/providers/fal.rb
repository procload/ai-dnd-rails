module ImageGeneration
  module Providers
    class Fal < Base
      def initialize(config)
        super({})  # Pass empty hash to parent to avoid validation conflicts
        logger.debug "[Fal.ai] Initializing with config: #{config.inspect}"
        @api_key = config[:api_key] || ENV['FAL_API_KEY']
        logger.debug "[Fal.ai] Using API key: #{@api_key ? '[PRESENT]' : '[MISSING]'}"
        @model = config[:model] || 'fal-ai/recraft-v3'
        
        validate_config!
      end

      def generate_image(prompt)
        logger.info "[Fal.ai] Generating image with prompt: #{prompt}"
        
        begin
          response = HTTP.auth("Key #{@api_key}")
                        .post("https://fal.run/#{@model}",
                          json: {
                            input: {
                              prompt: prompt,
                              image_size: "portrait_4_3",  # Using a portrait aspect ratio for character portraits
                              style: "realistic_image"     # Using realistic style for D&D characters
                            }
                          })
          
          result = JSON.parse(response.body.to_s)
          logger.debug "[Fal.ai] Raw response: #{result.inspect}"
          
          if response.status.success?
            {
              url: result['images'].first['url'],
              model: @model,
              provider: 'fal.ai',
              prompt: prompt
            }
          else
            logger.error "[Fal.ai] Error response: #{result.inspect}"
            { error: result['error'] || "Failed to generate image" }
          end
        rescue StandardError => e
          logger.error "[Fal.ai] Request failed: #{e.class} - #{e.message}"
          logger.error "[Fal.ai] Backtrace: #{e.backtrace.join("\n")}"
          { error: "Failed to generate image: #{e.message}" }
        end
      end

      private

      def validate_config!
        logger.debug "[Fal.ai] Validating config with API key #{@api_key ? 'present' : 'missing'}"
        raise ConfigurationError, "Missing Fal.ai API key" if @api_key.nil? || @api_key.empty?
      end
    end
  end
end 