# The Art of LLM Services in Rails

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

We've implemented a robust service architecture that follows Rails conventions:

```ruby
# app/services/llm/service.rb
module LLM
  class Service
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class ProviderError < Error; end

    class << self
      def chat(messages:, system_prompt: nil)
        new.chat(
          messages: messages,
          system_prompt: system_prompt
        )
      end

      def test_connection
        new.test_connection
      end
    end

    def initialize
      @provider = LLM::Factory.create_provider
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

### Provider Abstraction and Factory Pattern

We've implemented a flexible provider system using a factory pattern:

```ruby
# app/services/llm/factory.rb
module LLM
  class Factory
    class << self
      def create_provider
        provider_name = Rails.configuration.llm.provider
        config = Rails.configuration.llm.providers[provider_name]

        provider_class = case provider_name.to_sym
        when :anthropic
          LLM::Providers::Anthropic
        when :openai
          LLM::Providers::OpenAI
        when :mock
          LLM::Providers::Mock
        else
          raise LLM::Service::ConfigurationError, "Unknown provider: #{provider_name}"
        end

        provider_class.new(config)
      end
    end
  end
end
```

### Base Provider Interface

Our base provider class establishes a clear contract for all LLM providers:

```ruby
# app/services/llm/providers/base.rb
module LLM
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

        raise LLM::Service::ConfigurationError,
              "Missing required configuration keys: #{missing_keys.join(', ')}"
      end
    end
  end
end
```

### Configuration Management

We've implemented a flexible configuration system using Rails initializers:

```ruby
# config/initializers/llm.rb
Rails.application.configure do
  config.llm = ActiveSupport::OrderedOptions.new

  # Default to mock provider in development/test
  default_provider = Rails.env.production? ? :anthropic : :mock

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
end
```

### Mock Provider Implementation

We've maintained compatibility with our existing mock service while adapting it to our new interface:

```ruby
# app/services/llm/providers/mock.rb
module LLM
  module Providers
    class Mock < Base
      def chat(messages:, system_prompt: nil)
        log_request(:chat, messages: messages, system_prompt: system_prompt)

        last_message = messages.last
        return {} unless last_message['role'] == 'user'

        request = last_message['content']
        response = case request
                  when /background/i
                    generate_background
                  when /equipment/i
                    suggest_equipment
                  when /spells/i
                    suggest_spells
                  else
                    { error: 'Unknown request type' }
                  end

        log_response(:chat, response)
        response
      end
    end
  end
end
```

### Next Steps: Provider Implementations

We've made significant progress with our provider implementations:

#### Anthropic Claude Integration ✅

Our Anthropic Claude integration is now complete with:

- API client setup and configuration ✅
- Message formatting and schema validation ✅
- Response parsing and JSON extraction ✅
- Error handling and logging ✅
- Rate limiting implementation ✅
- Retry mechanisms ✅
- Comprehensive test suite ✅
- API version management ✅
  - Using version `2023-06-01`
  - Configurable through environment variables
- Model version management ✅
  - Updated to `claude-3-5-sonnet-20241022`
  - Configurable through environment variables

##### Rate Limiting and Retry Logic

[Original rate limiting content remains unchanged...]

##### API Version and Model Management

A key enhancement to our Anthropic integration is proper version management:

```ruby
module Llm
  module Providers
    class Anthropic < Base
      ANTHROPIC_API_VERSION = '2023-06-01'

      def make_request(messages:, schema:, request_type:)
        # ... existing setup ...

        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request['x-api-key'] = config[:api_key]
        request['anthropic-version'] = ANTHROPIC_API_VERSION

        # ... rest of method ...
      end
    end
  end
end
```

This ensures:

- Consistent API versioning across all requests
- Proper header management following Anthropic's latest standards
- Environment-based configuration through:
  ```ruby
  config.llm.providers = {
    anthropic: {
      model: ENV['ANTHROPIC_MODEL'] || 'claude-3-5-sonnet-20241022',
      # ... other config
    }
  }
  ```

The combination of explicit API versioning and configurable model versions helps maintain compatibility while allowing for easy updates as the API evolves.

#### OpenAI GPT-4 Integration ✅

Our OpenAI integration is now complete with the following features:

##### API Client Setup and Configuration

```ruby
module Llm
  module Providers
    class Openai < Base
      OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions'
      MAX_RETRIES = 3
      RETRY_DELAY = 1 # Base delay in seconds
      RATE_LIMIT_REQUESTS = 50 # Requests per minute
      RATE_LIMIT_WINDOW = 60 # Window in seconds

      def initialize(config)
        super
        validate_config!(:api_key, :model)
        @rate_limiter = RateLimiter.new(RATE_LIMIT_REQUESTS, RATE_LIMIT_WINDOW)
      end
    end
  end
end
```

##### Structured Output Handling

A key feature of our OpenAI implementation is the use of native JSON response formatting:

```ruby
request.body = {
  model: config[:model],
  messages: messages,
  response_format: { type: 'json_object' }, # Enforce JSON response format
  temperature: config[:temperature]
}.compact.to_json
```

This ensures consistent JSON responses without relying on message parsing or extraction.

##### Schema Validation and Request Types

We maintain consistent schemas across providers:

```ruby
def get_schema_for_request(request_type)
  case request_type
  when 'generate_background'
    {
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
  # ... other schemas ...
  end
end
```

##### Rate Limiting Implementation

Like our Anthropic provider, OpenAI uses a sliding window rate limiter:

```ruby
class RateLimiter
  def initialize(max_requests, window_seconds)
    @max_requests = max_requests
    @window_seconds = window_seconds
    @requests = []
  end

  def wait_if_needed
    now = Time.now
    @requests.reject! { |time| time < now - @window_seconds }

    if @requests.size >= @max_requests
      sleep_time = @requests.first + @window_seconds - now
      sleep(sleep_time) if sleep_time > 0
      @requests.shift
    end

    @requests << now
  end
end
```

##### Error Handling and Retries

Comprehensive error handling with exponential backoff:

```ruby
rescue Llm::Service::RateLimitError, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
  retries += 1
  if retries <= MAX_RETRIES
    sleep_time = [RETRY_DELAY * (2 ** (retries - 1)) + rand, 30].min
    Rails.logger.warn "[OpenAI] Request failed (attempt #{retries}/#{MAX_RETRIES}). Retrying in #{sleep_time} seconds..."
    sleep(sleep_time)
    retry
  else
    Rails.logger.error "[OpenAI] Request failed after #{MAX_RETRIES} retries: #{e.message}"
    raise Llm::Service::ProviderError, "Failed after #{MAX_RETRIES} retries: #{e.message}"
  end
```

##### Testing Strategy

Our test suite covers all major aspects of the OpenAI provider:

```ruby
class OpenaiTest < ActiveSupport::TestCase
  test 'chat returns structured background response' do
    messages = [{ 'role' => 'user', 'content' => 'Generate a background for a D&D character' }]

    stub_openai_request(body: background_response_body)

    response = @provider.chat(messages: messages)
    assert_kind_of Hash, response
    assert response.key?('background')
    assert response.key?('personality_traits')
    assert_kind_of Array, response['personality_traits']
  end

  # ... other tests ...
end
```

Key test scenarios include:

- Configuration validation
- Structured response handling
- Rate limit enforcement
- Retry logic
- Error scenarios
- Connection testing

##### Key Differences from Anthropic

1. **Authentication**

   - Uses `Authorization: Bearer` header instead of `X-Api-Key`
   - Follows OpenAI's authentication standards

2. **Response Format**

   - Uses OpenAI's native `response_format: { type: 'json_object' }`
   - Simpler JSON parsing due to guaranteed format
   - No need for complex JSON extraction from message content

3. **Message Structure**
   - Response contains `choices` array with message content
   - System messages handled as part of the messages array
   - Consistent with OpenAI's chat completion format

### The Prompt Service: Standardizing LLM Interactions

A key addition to our architecture is the Prompt Service, which provides a standardized way to manage prompts across different providers and request types.

#### Core Architecture

```ruby
module Llm
  class PromptService
    def self.generate(request_type:, provider:, **context)
      new.generate(
        request_type: request_type,
        provider: provider,
        **context
      )
    end

    def generate(request_type:, provider:, **context)
      template = load_template(request_type, provider)
      validate_template!(template)
      render_template(template, context)
    end

    private

    def load_template(request_type, provider)
      Rails.cache.fetch(cache_key(request_type, provider)) do
        load_template_from_disk(request_type, provider)
      end
    rescue TemplateNotFoundError => e
      Rails.logger.warn "[PromptService] #{e.message}, falling back to default template"
      load_default_template(request_type)
    end
  end
end
```

#### Template Structure

Our prompts are stored in YAML files, allowing for easy maintenance and version control:

```yaml
# config/prompts/default/character_background.yml
metadata:
  version: "1.0"
  description: "Template for generating D&D character backgrounds"
  last_updated: "2024-03-20"

configuration:
  temperature: 0.7
  max_tokens: 2000

schema:
  type: object
  required: ["background", "personality_traits"]
  properties:
    background:
      type: string
      description: "A detailed narrative of the character's history"
    personality_traits:
      type: array
      description: "List of personality traits"
      items:
        type: string
      minItems: 2
      maxItems: 4

system_prompt: |
  <system>
  You are a master storyteller and D&D character creation expert, specializing in crafting rich, 
  engaging backstories that incorporate high fantasy elements and make characters mysterious 
  and exciting to play.
  </system>

user_prompt: |
  Create a detailed background for {{name}}, a {{alignment}} {{race}} {{class}}:

  {{#traits}}
  - {{.}}
  {{/traits}}
```

#### Why YAML for Prompt Templates?

Our choice of YAML for prompt templates offers several advantages:

1. **Structured Data + Text Handling**

   - Combines configuration metadata with multiline prompts
   - Preserves formatting, including XML-style tags used by models like Claude
   - Supports complex data structures alongside text content

2. **Native Ruby Integration**

   - Built-in YAML support through `YAML.load_file`
   - Consistent with Rails conventions
   - No additional parsing gems required

3. **Template Inheritance and Overrides**

   ```ruby
   def load_template(request_type, provider)
     base = YAML.load_file(base_template_path(request_type))
     provider_specific = YAML.load_file(provider_template_path(request_type, provider))
     base.deep_merge(provider_specific)
   end
   ```

4. **Developer Experience**
   - Human-readable and easily editable
   - Supports inline documentation through comments
   - Clear visual hierarchy for complex templates

#### Template Rendering with Mustache

We use Mustache for template rendering, which provides several benefits:

1. **Simple Variable Interpolation**

   ```yaml
   Generate a background for a {{alignment}} {{race}} {{class}}
   ```

2. **Array Iteration**

   ```yaml
   {{#traits}}
   - {{.}}  # The dot represents the current item
   {{/traits}}
   ```

3. **Conditional Sections**
   ```yaml
   {{#optional_context}}
   Additional context: {{.}}
   {{/optional_context}}
   ```

#### Database Schema and Constraints

We've implemented a robust database schema to store character data:

```ruby
class AddBackgroundAndConstraintsToCharacters < ActiveRecord::Migration[8.0]
  def change
    add_column :characters, :background, :text

    # Set default values and add constraints
    execute(<<-SQL)
      -- Set default values for existing records
      UPDATE characters
      SET equipment = '{"weapons": [], "armor": [], "adventuring_gear": []}'::jsonb
      WHERE equipment IS NULL;

      -- Add array length constraints
      ALTER TABLE characters
      ADD CONSTRAINT equipment_arrays_length_check
      CHECK (
        jsonb_array_length(equipment->'weapons') BETWEEN 0 AND 4 AND
        jsonb_array_length(equipment->'armor') BETWEEN 0 AND 2 AND
        jsonb_array_length(equipment->'adventuring_gear') BETWEEN 0 AND 8
      );

      -- Add required keys constraints
      ALTER TABLE characters
      ADD CONSTRAINT equipment_required_keys_check
      CHECK (
        equipment ? 'weapons' AND
        equipment ? 'armor' AND
        equipment ? 'adventuring_gear'
      );
    SQL

    # Set NOT NULL constraints and defaults
    change_column_null :characters, :equipment, false
    change_column_default :characters, :equipment,
      { weapons: [], armor: [], adventuring_gear: [] }.to_json
  end
end
```

This migration ensures:

- All JSONB fields have proper structure
- Array lengths are constrained (e.g., max 4 weapons)
- Required keys are present
- Default values for new records
- NOT NULL constraints after data migration

#### Comprehensive Testing

Our test suite covers all aspects of the Prompt Service:

```ruby
class PromptServiceTest < ActiveSupport::TestCase
  test 'generates prompt from default template' do
    result = PromptService.generate(
      request_type: 'character_background',
      provider: :anthropic,
      name: 'Thalia',
      race: 'Half-Elf',
      class: 'Bard'
    )

    assert_includes result['user_prompt'], 'Thalia'
    assert_includes result['system_prompt'], 'master storyteller'
  end

  test 'respects provider-specific templates' do
    result = PromptService.generate(
      request_type: 'character_background',
      provider: :openai
    )

    refute_includes result['system_prompt'], '<system>'
    assert_includes result['system_prompt'], 'Guidelines:'
  end

  test 'validates template structure' do
    assert_raises(PromptService::ValidationError) do
      PromptService.generate(
        request_type: 'invalid_template',
        provider: :anthropic
      )
    end
  end
end
```

Key test areas include:

- Template loading and caching
- Provider-specific overrides
- Schema validation
- Error handling
- Integration with Character model

### Next Steps

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

This implementation provides a flexible foundation for integrating any LLM provider while maintaining Rails' principles of convention over configuration and clean, maintainable code.

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

This article demonstrates how we've evolved our prototype into a production-ready system while maintaining Rails' principles of convention over configuration and clean, maintainable code. Our implementation provides a flexible foundation for integrating any LLM provider while keeping the codebase organized and testable.

### The Power of Service Objects: Runtime Provider Switching

One of the most powerful features of our service architecture is the ability to dynamically switch LLM providers at runtime through simple configuration changes. This capability demonstrates several key benefits of Rails' service object pattern:

```ruby
# config/initializers/llm.rb
Rails.application.configure do
  config.llm = ActiveSupport::OrderedOptions.new

  # Switch providers with a single environment variable
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
