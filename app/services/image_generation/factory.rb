require_relative 'errors'

module ImageGeneration
  class Factory
    class << self
      def create_provider
        provider_name = Rails.configuration.image_generation.provider.to_sym
        config = Rails.configuration.image_generation.providers[provider_name]

        provider_class = case provider_name
        when :dalle
          ImageGeneration::Providers::DallE
        when :fal
          ImageGeneration::Providers::Fal
        else
          raise ConfigurationError, "Unknown provider: #{provider_name}"
        end

        provider_class.new(config)
      end
    end
  end
end 