# frozen_string_literal: true

require 'test_helper'

module Llm
  class PromptIntegrationTest < ActiveSupport::TestCase
    setup do
      @context = {
        'alignment' => 'Chaotic Good',
        'race' => 'Half-Elf',
        'class' => 'Bard',
        'traits' => ['Musician', 'Traveler']
      }
    end

    test 'integrates with Anthropic provider' do
      # Generate the prompt
      prompt = PromptService.generate(
        request_type: 'character_background',
        provider: :anthropic,
        **@context
      )

      # Create a mock provider for testing
      provider = Providers::Mock.new({})

      # Simulate the chat request
      response = provider.chat(
        messages: [
          { 'role' => 'system', 'content' => prompt['system_prompt'] },
          { 'role' => 'user', 'content' => prompt['user_prompt'] }
        ]
      )

      # Verify the response structure matches our schema
      assert_kind_of Hash, response
      assert_includes response, 'background'
      assert_includes response, 'personality_traits'
      assert_kind_of Array, response['personality_traits']
      assert response['personality_traits'].length.between?(2, 4)
    end

    test 'handles array context values correctly' do
      prompt = PromptService.generate(
        request_type: 'character_background',
        provider: :anthropic,
        **@context
      )

      # Verify that array values (traits) are properly formatted in the prompt
      @context['traits'].each do |trait|
        assert_includes prompt['user_prompt'], trait
      end
    end

    test 'configuration values are accessible' do
      template = YAML.load_file(
        Rails.root.join('config', 'prompts', 'default', 'character_background.yml')
      )

      # Verify configuration values are present
      assert_equal 0.7, template.dig('configuration', 'temperature')
      assert_equal 2000, template.dig('configuration', 'max_tokens')
    end

    test 'schema validation structure is correct' do
      template = YAML.load_file(
        Rails.root.join('config', 'prompts', 'default', 'character_background.yml')
      )

      schema = template['schema']
      assert_includes schema['required'], 'background'
      assert_includes schema['required'], 'personality_traits'
      assert_equal 'array', schema.dig('properties', 'personality_traits', 'type')
      assert_equal 2, schema.dig('properties', 'personality_traits', 'minItems')
      assert_equal 4, schema.dig('properties', 'personality_traits', 'maxItems')
    end
  end
end 