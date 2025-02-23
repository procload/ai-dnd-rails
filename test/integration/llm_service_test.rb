# frozen_string_literal: true

require "test_helper"

class LlmServiceIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @character = characters(:warrior)  # Assuming we have a warrior fixture
  end

  test "generates character traits using LLM service" do
    mock_response = {
      'traits' => [
        {
          'trait' => 'Brave',
          'description' => 'Always ready to face danger head-on'
        },
        {
          'trait' => 'Loyal',
          'description' => 'Stands by their companions through thick and thin'
        }
      ]
    }

    # Mock the prompt service first
    prompt = {
      'user_prompt' => 'Generate traits',
      'system_prompt' => nil
    }
    Llm::PromptService.expects(:generate)
                     .with(
                       request_type: 'character_traits',
                       provider: Rails.configuration.llm.provider,
                       name: @character.name,
                       race: @character.race,
                       class_type: @character.class_type,
                       level: @character.level,
                       alignment: @character.alignment,
                       background: @character.background
                     )
                     .returns(prompt)

    # Then mock the LLM service
    Llm::Service.any_instance.expects(:chat_with_schema)
                .with(
                  messages: [{ 'role' => 'user', 'content' => 'Generate traits' }],
                  schema: {
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
                )
                .returns(mock_response)

    # Store original traits to verify they change
    original_traits = @character.personality_traits.dup

    # Trigger trait generation
    @character.generate_traits

    # Verify traits were updated
    assert_not_equal original_traits, @character.personality_traits, "Traits should have been updated"
    assert_not_empty @character.personality_traits, "Traits should not be empty after generation"
    assert_equal 2, @character.personality_traits.length, "Should have generated 2 traits"
  end

  test "handles LLM service errors gracefully" do
    # Mock the prompt service first
    prompt = {
      'user_prompt' => 'Generate traits',
      'system_prompt' => nil
    }
    Llm::PromptService.expects(:generate)
                     .with(
                       request_type: 'character_traits',
                       provider: Rails.configuration.llm.provider,
                       name: @character.name,
                       race: @character.race,
                       class_type: @character.class_type,
                       level: @character.level,
                       alignment: @character.alignment,
                       background: @character.background
                     )
                     .returns(prompt)

    # Then mock the LLM service error
    Llm::Service.any_instance.expects(:chat_with_schema)
                .raises(Llm::Service::ProviderError.new("API error"))

    # Save the original traits
    original_traits = @character.personality_traits

    error = assert_raises(Llm::Service::ProviderError) do
      @character.generate_traits
    end

    assert_equal "Failed to generate traits: API error", error.message
    assert_equal original_traits, @character.personality_traits  # Traits should not change on error
  end

  test "can assign array to personality_traits directly" do
    test_traits = ["Trait 1: Description 1", "Trait 2: Description 2"]
    @character.personality_traits = test_traits
    assert @character.save
    assert_equal test_traits, @character.reload.personality_traits
  end
end 