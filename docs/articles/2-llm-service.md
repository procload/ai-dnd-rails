# The Art of LLM Services in Rails

## Article Outline

### Introduction

- The challenge of LLM integration
- Why service objects matter
- Rails' role in managing complexity
- Evolution from mock services to production

### From Mock to Production

- Analyzing our MockLlmService implementation
- Identifying the core interface
- Maintaining compatibility during transition
- Testing strategies for both implementations

### The Foundation: Service Architecture

- Basic service structure
- Provider abstraction
- Configuration management
- Error handling patterns

### Code Examples and Analysis

```ruby
module LLM
  class Service
    def self.chat(messages:, system_prompt: nil)
      new(config).chat(
        messages: messages,
        system_prompt: system_prompt
      )
    end

    def self.test_connection
      new(config).test_connection
    end
  end

  class Factory
    def self.create_provider
      provider_class = LLMConfig.provider_class
      provider = LLMConfig.provider
      config = LLMConfig.providers[provider]

      provider_class.new(config)
    end
  end
end
```

### Provider Implementation

- Base provider class
- Specific provider implementations (Anthropic, OpenAI)
- Rate limiting and quotas
- Error handling and retries
- Fallback strategies

### Real-World Integration

- Converting from synchronous to asynchronous processing
- Background job implementation
- Streaming responses through Turbo
- Managing job queues and concurrency
- Error recovery and retry mechanisms
- Handling timeouts and partial responses

### Testing Strategies

- Mocking LLM responses
- VCR for API testing
- Error scenarios
- Performance testing
- Testing both mock and production implementations

### Future Considerations

- Adding new providers
- Versioning considerations
- Performance optimization
- Scaling patterns
- Cost management and monitoring

This article builds directly on our mock service implementation from Article 1, showing how to evolve our prototype into a production-ready system while maintaining the simplicity and clarity that Rails encourages.
