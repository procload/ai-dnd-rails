# LLM Service Implementation Plan

This document tracks our progress in implementing the LLM service according to our established rules and requirements.

## Section 1: LLM Service Architecture Setup ✅

- [x] Define Service Interface

  - [x] Implemented `Llm::Service` class with routing to providers
  - [x] Created provider interface via `Llm::Providers::Base` class
  - [x] Established `chat(messages:, system_prompt: nil)` interface

- [x] Configuration Management

  - [x] Set up configuration in `config/initializers/llm.rb`
  - [x] Created `.env.example` with provider settings
  - [x] Implemented environment-based provider selection

- [x] Error Handling & Logging

  - [x] Added error handling in service layer
  - [x] Implemented comprehensive logging strategy
  - [x] Created custom error classes

- [x] Testing & Documentation
  - [x] Set up test structure using Rails' built-in Minitest
    - [x] Created service_test.rb for Llm::Service
    - [x] Created factory_test.rb for provider initialization
    - [x] Created mock_test.rb for mock provider
  - [x] Implemented test fixtures for mock data
  - [x] Added environment-specific path handling

## Testing Framework Decision ✅

We've chosen to use Rails' built-in Minitest framework over RSpec for the following reasons:

1. **Simplicity**

   - No additional dependencies
   - Clear, explicit assertions
   - No extra DSL to learn

2. **Rails Integration**

   - Native Rails test helpers
   - Follows Rails conventions
   - Built-in support for all our testing needs

3. **Maintainability**
   - Simpler debugging
   - Easier onboarding for new developers
   - Consistent with Rails philosophy

## Section 2: Provider Implementations 🚧

- [x] Mock Provider Implementation

  - [x] Created `Llm::Providers::Mock`
  - [x] Implemented chat and test_connection methods
  - [x] Added test fixtures and environment handling
  - [x] Ensured consistent response format (string keys)

- [x] Anthropic Provider Implementation

  - [x] Created `Llm::Providers::Anthropic`
  - [x] Implemented Claude API integration
  - [x] Added retry logic and rate limiting
  - [x] Added provider-specific tests
  - [x] Key considerations:
    - API client setup ✅
    - Message formatting ✅
    - Response parsing ✅
    - Error handling ✅
    - Rate limiting ✅
    - API version management ✅
    - Model version management ✅

- [x] OpenAI Provider Implementation

  - [x] Create `Llm::Providers::Openai`
  - [x] Implement GPT-4 API integration
  - [x] Add retry logic and rate limiting
  - [x] Add provider-specific tests
  - [x] Key considerations:
    - API client setup ✅
    - Message formatting ✅
    - Response parsing ✅
    - Error handling ✅

## Section 2.5: Prompt Service Implementation 🚧

**Objective:** Ensure consistent and modular prompt construction across different LLM providers.

- [x] Core Prompt Service

  - [x] Create `Llm::PromptService` class
  - [x] Define standard interface for prompt generation
  - [x] Implement prompt template loading and caching
  - [x] Add configuration system for prompt templates

- [x] Prompt Templates

  - [x] Design template structure for different request types:
    - [x] Character background generation
    - [x] Equipment suggestions
    - [x] Spell recommendations
  - [x] Create provider-specific variations:
    - [x] Anthropic Claude templates
    - [x] OpenAI GPT-4 templates

- [x] Template Configuration

  - [x] Set up YAML-based template storage
  - [x] Create initializer for template loading
  - [x] Add environment-specific template overrides
  - [x] Implement template validation

- [x] Provider Integration

  - [x] Update existing providers to use PromptService
  - [x] Add prompt parameter standardization
  - [x] Implement provider-specific transformations
  - [x] Add logging for prompt generation

- [x] Testing
  - [x] Unit tests for template loading
  - [x] Integration tests with providers
  - [x] Template validation tests
  - [x] Performance testing for template caching

## Section 3: Image Generation Service Integration 📝

- [ ] Service Structure

  - [ ] Create `ImageGeneration::Service`
  - [ ] Define provider interface
  - [ ] Implement configuration management

- [ ] Provider Implementation

  - [ ] Create OpenAI DALL-E provider
  - [ ] Add alternative provider option
  - [ ] Implement error handling

- [ ] Character Integration
  - [ ] Add portrait generation endpoint
  - [ ] Implement storage solution
  - [ ] Update character views

## Section 4: Background Job Integration 📝

- [ ] Job Setup

  - [ ] Create `LlmProcessingJob`
  - [ ] Create `ImageGenerationJob`
  - [ ] Implement job queuing

- [ ] Sidekiq Configuration

  - [ ] Set up Sidekiq
  - [ ] Configure job queues
  - [ ] Update controllers

- [ ] Error Handling
  - [ ] Implement retry strategies
  - [ ] Add job-specific logging
  - [ ] Handle timeouts

## Section 5: Testing and Documentation 🚧

- [x] Integration Testing

  - [x] Add end-to-end tests for LLM providers
  - [x] Test error scenarios
  - [ ] Test background jobs

- [ ] Documentation
  - [x] Update LLM service documentation
  - [x] Document configuration
  - [ ] Add troubleshooting guide

## Next Steps

1. Begin Image Generation Service Integration

   - Design service architecture
   - Research and select providers
   - Plan integration with character system

2. Set up Background Job Processing

   - Research Sidekiq configuration best practices
   - Design job structure for LLM and image generation
   - Plan error handling and retry strategies

3. Complete Documentation
   - Add troubleshooting guide
   - Document common error scenarios
   - Add deployment guide

## Lessons Learned

1. **Response Format Consistency**

   - Use string keys consistently in hashes
   - Define clear response structures
   - Provide sensible defaults

2. **Test Environment Isolation**

   - Separate test fixtures from development data
   - Validate fixture data automatically
   - Use environment-specific configurations

3. **Error Handling**

   - Graceful fallbacks for failures
   - Comprehensive logging
   - Clear error messages

4. **API Version Management**

   - Keep track of API versions in configuration
   - Update model versions as needed
   - Test version compatibility

5. **Rate Limiting**
   - Implement proper rate limiting
   - Use exponential backoff for retries
   - Add comprehensive logging for debugging

## Legend

- ✅ Complete
- 🚧 In Progress
- 📝 Not Started
