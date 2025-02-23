module ImageGeneration
  module Providers
    class Base
      require_relative '../errors'
      
      attr_reader :config

      def initialize(config = {})
        @config = config
      end

      def generate_image(prompt)
        raise NotImplementedError, "#{self.class} must implement #generate_image"
      end

      protected

      def validate_config!(*required_keys)
        missing_keys = required_keys.select { |key| config[key].nil? }
        return if missing_keys.empty?

        raise ImageGeneration::ConfigurationError,
              "Missing required configuration keys: #{missing_keys.join(', ')}"
      end

      def with_retries(max_retries: 3, base_delay: 1)
        retries = 0
        begin
          yield
        rescue StandardError => e
          retries += 1
          if retries <= max_retries
            sleep_time = base_delay * (2 ** (retries - 1))
            logger.warn "[#{self.class.name}] Request failed (attempt #{retries}/#{max_retries}). Retrying in #{sleep_time} seconds..."
            sleep(sleep_time)
            retry
          else
            raise ImageGeneration::ImageGenerationError, "Failed after #{max_retries} retries: #{e.message}"
          end
        end
      end

      private

      def logger
        Rails.logger
      end
    end
  end
end 