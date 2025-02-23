# frozen_string_literal: true

require "test_helper"

module Llm
  class ServiceTest < ActiveSupport::TestCase
    setup do
      @mock_provider = mock('provider')
      Llm::Factory.stubs(:create_provider).returns(@mock_provider)
      @service = Llm::Service.new
      @messages = [{ 'role' => 'user', 'content' => 'Generate a background' }]
      @schema = {
        'type' => 'object',
        'required' => ['background', 'personality_traits'],
        'properties' => {
          'background' => { 'type' => 'string' },
          'personality_traits' => {
            'type' => 'array',
            'items' => { 'type' => 'string' },
            'minItems' => 2,
            'maxItems' => 4
          }
        }
      }
    end

    test "chat delegates to provider and returns response" do
      mock_response = {
        'background' => 'A test background',
        'personality_traits' => ['Trait 1', 'Trait 2']
      }
      @mock_provider.expects(:chat)
                   .with(messages: @messages, system_prompt: nil)
                   .returns(mock_response)
                   .once

      response = @service.chat(messages: @messages)
      assert_equal mock_response, response
    end

    test "chat_with_schema validates response against schema" do
      mock_response = {
        'background' => 'A test background',
        'personality_traits' => ['Trait 1', 'Trait 2']
      }
      @mock_provider.expects(:chat_with_schema)
                   .with(messages: @messages, system_prompt: nil, schema: @schema)
                   .returns(mock_response)
                   .once

      response = @service.chat_with_schema(
        messages: @messages,
        schema: @schema
      )

      assert_equal mock_response, response
    end

    test "handles provider errors gracefully" do
      # The service will make MAX_RETRIES + 1 attempts (initial + retries)
      @mock_provider.expects(:chat)
                   .with(messages: @messages, system_prompt: nil)
                   .raises(StandardError.new("API error"))
                   .times(4)  # Initial attempt + 3 retries

      error = assert_raises(Llm::Service::ProviderError) do
        @service.chat(messages: @messages)
      end
      assert_equal "Failed to process chat request: API error", error.message
    end

    test "retries on rate limit errors" do
      mock_response = { 'background' => 'Success after retry' }
      
      sequence = sequence('retry_sequence')
      
      @mock_provider.expects(:chat)
                   .with(messages: @messages, system_prompt: nil)
                   .raises(Llm::Service::RateLimitError.new("Rate limited"))
                   .in_sequence(sequence)

      @mock_provider.expects(:chat)
                   .with(messages: @messages, system_prompt: nil)
                   .returns(mock_response)
                   .in_sequence(sequence)

      response = @service.chat(messages: @messages)
      assert_equal mock_response, response
    end
  end
end 