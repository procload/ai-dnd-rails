# frozen_string_literal: true

require "test_helper"

module Llm
  module Providers
    class MockTest < ActiveSupport::TestCase
      setup do
        @config = {
          model: 'test-model',
          max_tokens: 1000,
          temperature: 0.7
        }
        @provider = Mock.new(@config)
      end

      test "chat returns a valid response" do
        messages = [{ 'role' => 'user', 'content' => 'Generate a background' }]
        response = @provider.chat(messages: messages)

        assert_kind_of Hash, response
        assert response.key?('background')
        assert response.key?('personality_traits')
      end

      test "chat_with_schema validates response against schema" do
        messages = [{ 'role' => 'user', 'content' => 'Generate traits' }]
        schema = {
          'type' => 'object',
          'required' => ['traits'],
          'properties' => {
            'traits' => {
              'type' => 'array',
              'items' => {
                'type' => 'object',
                'required' => ['trait', 'description'],
                'properties' => {
                  'trait' => { 'type' => 'string' },
                  'description' => { 'type' => 'string' }
                }
              },
              'minItems' => 2,
              'maxItems' => 4
            }
          }
        }

        response = @provider.chat_with_schema(
          messages: messages,
          schema: schema
        )

        assert_kind_of Hash, response
        assert response.key?('traits')
        assert response['traits'].length.between?(2, 4)
        assert response['traits'].all? { |t| t.key?('trait') && t.key?('description') }
      end

      test "test_connection returns true" do
        assert @provider.test_connection
      end
    end
  end
end 