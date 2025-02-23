module ImageGeneration
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ProviderError < Error; end
  class ImageGenerationError < Error; end
end 