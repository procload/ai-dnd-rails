# The Art of LLM Services in Rails [✓ Complete]

## Overview

This article details our journey from a basic mock service to a production-ready LLM integration system in Rails. Through implementing a D&D character generator, we demonstrate how Rails' conventions and service objects provide an elegant foundation for AI-powered applications.

## Key Achievements

1. **Provider System**

   - Flexible provider abstraction with schema validation
   - Environment-aware provider selection
   - Comprehensive error handling and retries
   - Rate limiting with exponential backoff

2. **Structured Responses**

   - Provider-agnostic JSON schemas
   - Native provider-specific formatting
   - Robust validation and error handling
   - Consistent response structures

3. **Testing & Reliability**

   - Mock provider for development/testing
   - Rate limiting and retry mechanisms
   - Comprehensive logging
   - Schema validation

4. **Feature Migration**
   - All character features migrated
   - Backward compatibility maintained
   - Rollback procedures in place

## Article Outline

### Introduction

- The challenge of LLM integration in Rails applications
- Why service objects matter for AI integration
- Rails' role in managing complexity through convention
- Evolution from mock services to production-ready implementations

### From Mock to Production

#### Mock Provider Implementation

We started with a mock provider to establish our interface and testing patterns. Key decisions included:

1. **Consistent Data Structure**

   ```ruby
   # Response format using string keys (not symbols) for consistency
   {
     'background' => 'Character background story...',
     'personality_traits' => ['Trait 1', 'Trait 2']
   }
   ```

2. **Test Environment Setup**

   - Using Rails fixtures for test data
   - Maintaining separate mock data paths for test/development

   ```ruby
   def load_json(filename)
     path = if Rails.env.test?
             Rails.root.join('test', 'fixtures', 'files', filename)
           else
             Rails.root.join('mock', 'responses', filename)
           end
     # ...
   end
   ```

3. **Error Handling**
   - Graceful fallbacks for missing files
   - Default responses for empty data
   - Comprehensive logging

#### Testing Strategy

Our testing approach focuses on:

1. **Interface Consistency**

   ```ruby
   test "chat delegates to provider and returns valid response" do
     response = service.chat(messages: [{ 'role' => 'user', 'content' => 'background' }])
     assert_kind_of Hash, response
     assert response.key?('background')
     assert response.key?('personality_traits')
   end
   ```

2. **Environment Isolation**

   - Separate test fixtures from development data
   - Environment-specific provider configuration
   - Automated fixture validation

3. **Error Cases**
   - Invalid message formats
   - Missing data files
   - Malformed responses

### The Foundation: Service Architecture

```ruby
# app/services/llm/service.rb
module Llm
  class Service
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class ProviderError < Error; end
    class RateLimitError < ProviderError; end

    MAX_RETRIES = 3
    RETRY_DELAY = 1 # seconds

    class << self
      def chat(messages:, system_prompt: nil)
        new.chat(messages: messages, system_prompt: system_prompt)
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
      Rails.logger.info "[LLM::Service] Sending chat request with #{messages.length} messages"

      @provider.chat(
        messages: messages,
        system_prompt: system_prompt
      )
    rescue StandardError => e
      Rails.logger.error "[LLM::Service] Error in chat: #{e.class} - #{e.message}"
      raise ProviderError, "Failed to process chat request: #{e.message}"
    end
  end
end
```

### Configuration Management

```ruby
# config/initializers/llm.rb
Rails.application.configure do
  config.llm = ActiveSupport::OrderedOptions.new

  # Environment-aware provider selection
  default_provider = case Rails.env
                    when 'test'
                      :mock
                    else
                      :anthropic
                    end

  config.llm.provider = (ENV['LLM_PROVIDER'] || default_provider).to_sym

  config.llm.providers = {
    anthropic: {
      api_key: ENV['ANTHROPIC_API_KEY'],
      model: ENV['ANTHROPIC_MODEL'] || 'claude-3-5-sonnet-20241022',
      max_tokens: (ENV['ANTHROPIC_MAX_TOKENS'] || 4096).to_i,
      temperature: (ENV['ANTHROPIC_TEMPERATURE'] || 0.7).to_f
    },
    openai: {
      api_key: ENV['OPENAI_API_KEY'],
      model: ENV['OPENAI_MODEL'] || 'gpt-4-turbo-preview',
      max_tokens: (ENV['OPENAI_MAX_TOKENS'] || 4096).to_i,
      temperature: (ENV['OPENAI_TEMPERATURE'] || 0.7).to_f
    },
    mock: {
      # Mock provider doesn't need configuration
    }
  }

  # Production validation
  if Rails.env.production?
    provider = config.llm.provider
    provider_config = config.llm.providers[provider]

    unless provider_config
      raise "Invalid LLM provider configured: #{provider}"
    end

    if provider != :mock && !provider_config[:api_key]
      raise "Missing API key for LLM provider: #{provider}"
    end
  end
end
```

### Provider Interface

```ruby
# app/services/llm/providers/base.rb
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
    end
  end
end
```

### Schema Validation

A key feature of our implementation is robust schema validation:

```ruby
def validate_schema!(schema)
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

  # Validate array properties
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
```

### Testing Strategy

Our testing strategy should include:

1. **Service Tests**

```ruby
# test/services/llm/service_test.rb
class Llm::ServiceTest < ActiveSupport::TestCase
  test "chat delegates to provider and returns valid response" do
    response = @service.chat(
      messages: [{ 'role' => 'user', 'content' => 'Generate a background' }]
    )
    assert_kind_of Hash, response
    assert response.key?('background')
  end

  test "chat_with_schema validates response against schema" do
    schema = {
      'type' => 'object',
      'required' => ['background'],
      'properties' => {
        'background' => { 'type' => 'string' }
      }
    }

    response = @service.chat_with_schema(
      messages: [{ 'role' => 'user', 'content' => 'Generate a background' }],
      schema: schema
    )
    assert_kind_of Hash, response
    assert response.key?('background')
    assert_kind_of String, response['background']
  end
end
```

2. **Provider Tests**

```ruby
# test/services/llm/providers/anthropic_test.rb
class Llm::Providers::AnthropicTest < ActiveSupport::TestCase
  setup do
    @provider = Llm::Providers::Anthropic.new(
      api_key: 'test_key',
      model: 'claude-3-5-sonnet-20241022'
    )
  end

  test "handles rate limiting with exponential backoff" do
    # Test implementation
  end

  test "validates schema structure" do
    # Test implementation
  end
end
```

3. **Integration Tests**

```ruby
# test/integration/character_generation_test.rb
class CharacterGenerationTest < ActionDispatch::IntegrationTest
  test "generates character background with traits" do
    character = characters(:warrior)

    assert_changes -> { character.background.to_plain_text },
                  -> { character.personality_traits } do
      character.generate_background
    end
  end
end
```

### Next Steps

1. **Testing Implementation**

   - Complete test suite implementation
   - Add VCR for API testing
   - Implement integration tests
   - Add performance benchmarks

2. **Schema Management**

   - Centralize schema definitions
   - Add schema versioning
   - Implement schema migration system

3. **Monitoring and Analytics**

   - Add request tracking
   - Implement cost monitoring
   - Add quality metrics
   - Set up error tracking

4. **Performance Optimization**
   - Implement response caching
   - Add request batching
   - Optimize rate limiting
   - Add provider fallbacks

### Real-World Integration (Coming Soon)

- Converting to asynchronous processing
- Background job implementation
- Streaming responses through Turbo
- Managing job queues and concurrency
- Error recovery and retry mechanisms
- Handling timeouts and partial responses

### Testing Strategies (In Progress)

Our testing strategy now includes:

- Unit tests for service configuration ✅
- Provider-specific test suites 🚧
- Template validation tests (Coming Soon)
- VCR for API testing
- Error scenario coverage
- Performance benchmarking

### Future Considerations

Our roadmap includes:

1. **Prompt Management**

   - Template versioning system
   - A/B testing capabilities
   - Performance analytics

2. **Provider Expansion**

   - Additional LLM providers
   - Specialized models for specific tasks
   - Fallback providers

3. **Performance Optimization**

   - Response caching
   - Request batching
   - Cost optimization

4. **Monitoring and Analytics**
   - Usage tracking
   - Cost monitoring
   - Quality metrics

This article demonstrates how we've evolved our prototype into a production-ready system while maintaining Rails' principles of convention over configuration and clean, maintainable code. Our implementation provides a flexible foundation for integrating any LLM provider while maintaining Rails' principles of convention over configuration and clean, maintainable code.

### The Power of Service Objects: Runtime Provider Switching

One of the most powerful features of our service architecture is the ability to dynamically switch LLM providers at runtime through simple configuration changes. This capability demonstrates several key benefits of Rails' service object pattern:

```ruby
# config/initializers/llm.rb
Rails.application.configure do
  config.llm = ActiveSupport::OrderedOptions.new

  # Default to mock provider in development/test
  default_provider = Rails.env.production? ? :anthropic : :mock
  config.llm.provider = (ENV['LLM_PROVIDER'] || default_provider).to_sym

  # Configure available providers
  config.llm.providers = {
    anthropic: {
      api_key: ENV['ANTHROPIC_API_KEY'],
      model: ENV['ANTHROPIC_MODEL'] || 'claude-3-5-sonnet-20241022',
      max_tokens: (ENV['ANTHROPIC_MAX_TOKENS'] || 4096).to_i,
      temperature: (ENV['ANTHROPIC_TEMPERATURE'] || 0.7).to_f
    },
    openai: {
      api_key: ENV['OPENAI_API_KEY'],
      model: ENV['OPENAI_MODEL'] || 'gpt-4-turbo-preview',
      max_tokens: (ENV['OPENAI_MAX_TOKENS'] || 4096).to_i,
      temperature: (ENV['OPENAI_TEMPERATURE'] || 0.7).to_f
    },
    mock: {
      # Mock provider doesn't need configuration
    }
  }
end
```

This architecture provides several key advantages:

1. **Environment-Based Configuration**

   - Development environments can use the mock provider by default
   - Production can use a different default provider
   - Easy to override with environment variables

2. **Zero-Code Provider Switching**

   ```bash
   # Switch to OpenAI
   export LLM_PROVIDER=openai
   export OPENAI_API_KEY=your_key_here

   # Switch to Anthropic
   export LLM_PROVIDER=anthropic
   export ANTHROPIC_API_KEY=your_key_here

   # Switch to mock for testing
   export LLM_PROVIDER=mock
   ```

3. **Consistent Interface**

   - All providers implement the same interface
   - Application code remains unchanged regardless of provider
   - Easy to add new providers without modifying existing code

4. **Development and Testing Benefits**

   - Mock provider for fast, free development
   - Easy to switch providers for testing
   - No API keys needed in development by default

5. **Production Flexibility**
   - A/B test different LLM providers
   - Easy fallback to alternative providers
   - Cost optimization by switching providers

This implementation showcases several Rails best practices:

1. **Service Objects**

   - Encapsulate LLM interaction logic
   - Provide a clean interface to the rest of the application
   - Make testing and mocking straightforward

2. **Factory Pattern**

   ```ruby
   module Llm
     class Factory
       def self.create_provider
         provider_name = Rails.configuration.llm.provider
         config = Rails.configuration.llm.providers[provider_name]

         provider_class = case provider_name.to_sym
         when :anthropic then Llm::Providers::Anthropic
         when :openai then Llm::Providers::Openai
         when :mock then Llm::Providers::Mock
         else
           raise Llm::Service::ConfigurationError, "Unknown provider: #{provider_name}"
         end

         provider_class.new(config)
       end
     end
   end
   ```

3. **Configuration Management**

   - Use Rails' configuration system
   - Environment-based defaults
   - Easy override through environment variables

4. **Error Handling**
   - Graceful provider initialization failures
   - Clear error messages for configuration issues
   - Proper logging of provider-specific errors

This architecture makes it trivial to:

- Switch between providers for testing
- Compare different LLM outputs
- Handle provider outages
- Optimize costs
- Add new providers
  All without changing application code.

## Image Generation Service Implementation

Building upon our LLM service architecture, we're now implementing an image generation service that follows similar patterns while leveraging Rails 8's newest features. This service will handle character portrait generation based on the background and traits we generate through our LLM service.

### Service Architecture Overview

Our image generation service follows the same provider pattern as our LLM service, but with some key differences:

```ruby
module ImageGeneration
  class Service
    include ActiveModel::API  # New in Rails 8
    include ActiveModel::Attributes

    attribute :character
    attribute :prompt_type

    class << self
      def generate(character:, prompt_type: :portrait)
        new(character: character, prompt_type: prompt_type).generate
      end
    end

    def generate
      Rails.logger.info "[ImageGeneration::Service] Generating image for character #{character.id}"

      prompt = PromptService.generate(
        request_type: 'character_image',
        provider: provider_name,
        character: character
      )

      provider.generate_image(prompt)
    rescue StandardError => e
      Rails.logger.error "[ImageGeneration::Service] Error generating image: #{e.class} - #{e.message}"
      raise ImageGenerationError, "Failed to generate image: #{e.message}"
    end

    private

    def provider
      @provider ||= ImageGeneration::Factory.create_provider
    end
  end
end
```

### Provider Pattern Implementation

Like our LLM service, we implement a base provider that defines the interface:

```ruby
module ImageGeneration
  module Providers
    class Base
      include ActiveModel::API
      include ActiveModel::Attributes

      attribute :config

      def initialize(config)
        @config = config
        validate_config!
      end

      def generate_image(prompt)
        raise NotImplementedError, "#{self.class} must implement #generate_image"
      end

      protected

      def validate_config!(*required_keys)
        missing_keys = required_keys.select { |key| config[key].nil? }
        return if missing_keys.empty?

        raise ConfigurationError,
              "Missing required configuration keys: #{missing_keys.join(', ')}"
      end
    end
  end
end
```

### DALL-E Provider Integration

Our initial provider implementation uses OpenAI's DALL-E:

```ruby
module ImageGeneration
  module Providers
    class DallE < Base
      DALLE_API_VERSION = '2024-03'
      MAX_RETRIES = 3
      RETRY_DELAY = 1

      def generate_image(prompt)
        validate_config!(:api_key, :model)

        with_retries do
          response = make_request(prompt)
          process_response(response)
        end
      end

      private

      def make_request(prompt)
        uri = URI('https://api.openai.com/v1/images/generations')
        request = Net::HTTP::Post.new(uri)
        request['Authorization'] = "Bearer #{config[:api_key]}"
        request['Content-Type'] = 'application/json'
        request.body = {
          model: config[:model],
          prompt: prompt,
          size: '1024x1024',
          quality: 'standard',
          n: 1
        }.to_json

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        JSON.parse(response.body)
      end

      def process_response(response)
        return { error: response['error'] } if response['error']

        {
          url: response.dig('data', 0, 'url'),
          created: Time.current
        }
      end

      def with_retries
        retries = 0
        begin
          yield
        rescue StandardError => e
          retries += 1
          if retries <= MAX_RETRIES
            sleep_time = RETRY_DELAY * (2 ** (retries - 1))
            Rails.logger.warn "[DALL-E] Request failed (attempt #{retries}/#{MAX_RETRIES}). Retrying in #{sleep_time} seconds..."
            sleep(sleep_time)
            retry
          else
            raise ImageGenerationError, "Failed after #{MAX_RETRIES} retries: #{e.message}"
          end
        end
      end
    end
  end
end
```

### Active Storage Integration

We leverage Rails 8's enhanced Active Storage features for handling the generated images:

```ruby
class Character < ApplicationRecord
  has_one_attached :profile_image do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 100]
    attachable.variant :medium, resize_to_limit: [300, 300]
  end

  enum image_status: { pending: 0, generating: 1, completed: 2 }, prefix: true

  encrypts :image_metadata
end
```

### Modern UI Integration

Our UI implementation leverages Rails 8's Turbo and Stimulus features for a seamless user experience:

```erb
<%# app/views/characters/_current_portrait.html.erb %>
<div id="current_portrait" class="bg-white shadow rounded-lg p-6">
  <div class="flex justify-between items-start mb-4">
    <h3 class="text-lg font-medium text-gray-900">Character Portrait</h3>

    <div class="flex space-x-2">
      <%= button_to generate_portrait_character_path(character),
                    method: :post,
                    class: "inline-flex items-center px-3 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700",
                    data: {
                      turbo: true,
                      controller: "loading",
                      action: "turbo:submit-start->loading#start turbo:submit-end->loading#end",
                    } do %>
        Generate New Portrait
      <% end %>
    </div>
  </div>
</div>
```

Key features of our UI implementation include:

1. **Portrait Gallery**

   - Historical view of all generated portraits
   - Easy selection between different portraits
   - Real-time updates using Turbo Streams

2. **Loading States**

   - Visual feedback during generation
   - Error handling with user-friendly messages
   - Automatic UI updates on completion

3. **Responsive Design**
   - Mobile-friendly layout
   - Optimized image loading
   - Smooth transitions

### Enhanced Logging Implementation

We've implemented comprehensive logging throughout the image generation process:

```ruby
def generate
  logger.info "\n=== Starting Image Generation ===\n" \
              "Character: #{character.name} (ID: #{character.id})\n" \
              "Provider: #{provider_name}\n" \
              "Prompt Type: #{prompt_type}\n" \
              "================================"

  validate_character!
  character.update!(image_status: :generating)

  prompt = Llm::PromptService.generate(
    request_type: 'character_image',
    provider: provider_name,
    **character_details
  )
  logger.info "\n=== Image Generation Prompt ===\n" \
             "System Prompt: #{prompt['system_prompt']}\n" \
             "User Prompt: #{prompt['user_prompt']}\n" \
             "=== End Prompt ===\n"

  result = provider.generate_image(prompt['user_prompt'])
  attach_image(result, prompt['user_prompt'])
rescue StandardError => e
  character.update!(image_status: :pending)
  logger.error "Error during image generation: #{e.class} - #{e.message}"
  logger.error "Backtrace: #{e.backtrace.join("\n")}"
  raise ImageGenerationError, "Failed to generate image: #{e.message}"
end
```

Our logging strategy includes:

1. **Structured Log Format**

   - Clear section headers
   - Consistent timestamp format
   - Severity level indicators
   - Process and request IDs

2. **Development Environment Configuration**

   ```ruby
   # config/environments/development.rb
   config.log_level = :debug
   config.logger = ActiveSupport::Logger.new(STDOUT)
   config.active_record.verbose_query_logs = true
   config.active_record.query_log_tags_enabled = true
   ```

3. **Process Tracking**

   - Generation start and completion
   - Prompt details
   - Error states and recovery
   - Image attachment status

4. **Performance Monitoring**
   - API response times
   - Image download duration
   - Storage attachment metrics

### Portrait Model Implementation

We've implemented a dedicated model for managing character portraits:

```ruby
class CharacterPortrait < ApplicationRecord
  belongs_to :character
  has_one_attached :image do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 100]
    attachable.variant :medium, resize_to_limit: [300, 300]
  end

  validates :character, presence: true

  scope :selected, -> { where(selected: true) }
  scope :most_recent_first, -> { order(created_at: :desc) }

  after_save :ensure_only_one_selected, if: :selected?

  private

  def ensure_only_one_selected
    character.character_portraits.where.not(id: id).update_all(selected: false)
  end
end
```

Key features include:

1. **Image Variants**

   - Automatic thumbnail generation
   - Optimized sizes for different views
   - Lazy loading support

2. **Selection Management**

   - Single selected portrait per character
   - Automatic deselection of other portraits
   - History tracking

3. **Metadata Storage**
   - Generation prompt preservation
   - Provider response details
   - Creation timestamps

This implementation provides a robust foundation for managing character portraits while maintaining a clean and efficient codebase that follows Rails conventions.

### Implementing Structured JSON Responses

One of the key challenges in working with LLMs is getting consistent, structured responses that can be reliably parsed and used in your application. Both Anthropic and OpenAI provide different approaches to this problem:

- Anthropic uses tool calling to enforce structure
- OpenAI uses response_format with JSON schemas

#### The Challenge

When working with LLMs, you often encounter these issues:

1. Inconsistent response formats
2. Missing required fields
3. Invalid JSON structure
4. Extra conversational text mixed with JSON
5. Different provider approaches to structured data

#### The Solution: Provider-Agnostic Schema Structure

We've implemented a solution that works with both providers while maintaining a clean abstraction. Our solution leverages a provider-agnostic schema structure in YAML that can be translated to each provider's specific requirements:

```yaml
# config/prompts/default/character_traits.yml
name: character_traits
description: Generate character traits using structured output
version: 1.0

# Standard prompt fields (backward compatibility)
system_prompt: |
  You are a D&D character trait generator. Generate traits that are unique and fitting for the character's class and background.
  Focus on traits that would be interesting to roleplay and that fit the character's class archetype.

user_prompt: |
  Generate {{count}} distinctive traits for a level {{level}} {{alignment}} {{class}} named {{name}}.
  The traits should reflect their background and experience level.

# Schema definition (used by both providers)
schema:
  type: object
  required: [traits]
  properties:
    traits:
      type: array
      items:
        type: object
        required: [trait, description]
        properties:
          trait:
            type: string
            description: A single word or short phrase describing the trait
          description:
            type: string
            description: A brief explanation of how this trait manifests
      minItems: 2
      maxItems: 4

# Provider-specific configurations
providers:
  anthropic:
    tool_config:
      name: character_traits
      description: Generate character traits in a structured format
      input_schema: $schema # References the schema above

  openai:
    response_format:
      type: json_schema
      schema: $schema # References the schema above
      strict: true
```

#### Using the Structured Response System

Here's how to use the structured response system in your application:

```ruby
class Character < ApplicationRecord
  def generate_traits
    # Get the prompt from our PromptService
    prompt = Llm::PromptService.generate(
      request_type: 'character_traits',
      provider: Rails.configuration.llm.provider,
      name: name,
      race: race,
      class: class_type,
      level: level,
      alignment: alignment
    )

    # Send the request to our LLM service with schema validation
    response = Llm::Service.chat_with_schema(
      messages: [
        {
          'role' => 'user',
          'content' => prompt['user_prompt']
        }
      ],
      system_prompt: prompt['system_prompt'],
      schema: prompt['schema']
    )

    # Update the character with the new traits
    update!(personality_traits: response['traits'].map { |t| "#{t['trait']}: #{t['description']}" })
  rescue StandardError => e
    Rails.logger.error("Failed to generate traits: #{e.message}")
    raise Llm::Service::ProviderError, "Failed to generate traits: #{e.message}"
  end
end
```

#### Implementation Benefits

This approach provides several key benefits:

1. **Provider Agnostic**

   - Same schema works with any provider
   - Easy to switch providers
   - Consistent interface across the application

2. **Type Safety**

   - Guaranteed response structure
   - Early validation failures
   - Clear error messages

3. **Developer Experience**

   - Simple YAML configuration
   - Clear separation of concerns
   - Easy to extend for new providers

4. **Maintainability**
   - Centralized schema definitions
   - Provider-specific details isolated
   - Common validation and error handling

#### Schema Validation

The base provider implements robust schema validation:

```ruby
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
```

#### Provider-Specific Implementations

Each provider implements the interface according to its specific requirements:

```ruby
# Anthropic Implementation
module Llm
  module Providers
    class Anthropic < Base
      def chat_with_schema(messages:, system_prompt: nil, schema:)
        validate_schema!(schema)

        tool_config = {
          name: 'json_output',
          description: 'Return a structured JSON object following the schema',
          input_schema: schema
        }

        response = make_request(
          messages: messages,
          system_prompt: system_prompt,
          tool_config: tool_config
        )

        handle_response(response)
      end
    end
  end
end

# OpenAI Implementation
module Llm
  module Providers
    class OpenAi < Base
      def chat_with_schema(messages:, system_prompt: nil, schema:)
        validate_schema!(schema)

        response = make_request(
          messages: messages,
          system_prompt: system_prompt,
          response_format: {
            type: 'json_schema',
            json_schema: {
              schema: schema,
              strict: true
            }
          }
        )

        handle_response(response)
      end
    end
  end
end
```

### Next Steps

Our implementation is now complete and in production use. Future enhancements may include:

1. **Asynchronous Processing**

   - Background job implementation
   - Streaming responses
   - Queue management

2. **Performance Optimization**

   - Response caching
   - Request batching
   - Cost management

3. **Monitoring and Analytics**

   - Usage tracking
   - Error rate monitoring
   - Response quality metrics

4. **Provider Expansion**
   - Additional LLM providers
   - Specialized model integration
   - Fallback mechanisms

This implementation provides a flexible foundation for working with structured LLM responses while maintaining clean code and Rails conventions.

#### Handling Model Updates with Structured Responses

When implementing structured responses that update model attributes, it's important to consider how the updates interact with model validations. Here's how we handle this in our trait generation feature:

```ruby
def generate_traits
  # Get structured response from LLM
  response = Llm::Service.chat_with_schema(
    messages: [...],
    system_prompt: prompt['system_prompt'],
    schema: prompt['schema']
  )

  # Update only the specific attribute and skip validation
  self.personality_traits = response['traits'].map { |t| "#{t['trait']}: #{t['description']}" }
  save!(validate: false)
rescue StandardError => e
  raise Llm::Service::ProviderError, "Failed to generate traits: #{e.message}"
end
```

Key considerations:

1. Use `save!(validate: false)` when updating specific attributes to avoid triggering full model validation
2. Only update the attributes that are being modified by the LLM
3. Handle the response transformation before saving to ensure data consistency
4. Maintain proper error handling and logging

This approach allows us to:

- Update individual attributes without validating unrelated fields
- Maintain data integrity while being flexible with LLM updates
- Keep the code focused and maintainable
- Prevent validation errors from blocking valid content updates

The implementation successfully works with both Anthropic's tool-based approach and OpenAI's response format, providing a consistent interface for structured data generation across providers.

### Structured Content Display

One of the challenges in working with LLM-generated content is presenting it in a structured, user-friendly way. Our character background implementation demonstrates an effective approach to this problem.

#### Background Structure

We structure the background content into four distinct sections:

1. Early Life & Upbringing
2. Pivotal Moments
3. Path to Adventuring
4. Unresolved Mysteries

This structure is enforced at three levels:

1. **Schema Definition**

```yaml
schema:
  type: object
  required:
    - early_life
    - pivotal_moments
    - recent_history
    - unresolved_mysteries
  properties:
    early_life:
      type: string
      description: The character's early life and upbringing
    pivotal_moments:
      type: string
      description: Key moments that shaped the character
    recent_history:
      type: string
      description: Path to becoming an adventurer
    unresolved_mysteries:
      type: string
      description: Open questions and future potential
```

2. **Content Template**

```erb
<h3>Early Life & Upbringing</h3>
<%= early_life %>

<h3>Pivotal Moments</h3>
<%= pivotal_moments %>

<h3>Path to Adventuring</h3>
<%= recent_history %>

<h3>Unresolved Mysteries</h3>
<%= unresolved_mysteries %>
```

3. **Display Template**

```erb
<div class="mt-4 space-y-4">
  <!-- Early Life -->
  <div class="bg-gray-50 rounded-lg p-4">
    <h4 class="text-sm font-medium text-gray-900 mb-2">
      Early Life & Upbringing
    </h4>
    <div class="prose prose-sm max-w-none text-gray-700">
      <%= content %>
    </div>
  </div>
  <!-- Additional sections follow same pattern -->
</div>
```

#### Rich Text Integration

While we store the content as a single Rich Text field for flexibility, we maintain structure through:

1. **Consistent Section Headers**: Used as delimiters for content parsing
2. **Template-Based Generation**: Ensures consistent formatting
3. **Semantic HTML**: Proper heading hierarchy and content organization
4. **Tailwind CSS Styling**: Consistent visual presentation

This approach provides several benefits:

1. **Maintainable Structure**: Changes to section organization only need to be made in one place
2. **Consistent Styling**: Each section follows the same visual pattern
3. **Flexible Content**: Rich text allows for future enhancements like embedded images or links
4. **Clear Organization**: Users can easily navigate between different aspects of the background

The implementation successfully balances structured data requirements with the flexibility needed for creative content generation.
