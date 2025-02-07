# frozen_string_literal: true

require 'test_helper'

module Llm
  class PromptServiceTest < ActiveSupport::TestCase
    setup do
      @service = PromptService.new
      @request_type = 'character_background'
      @provider = :anthropic
      @context = {
        'name' => 'Thalia Stormwind',
        'alignment' => 'Chaotic Good',
        'race' => 'Half-Elf',
        'class' => 'Bard',
        'traits' => ['Musician', 'Traveler']
      }
    end

    test 'generates prompt from default template' do
      result = PromptService.generate(
        request_type: @request_type,
        provider: @provider,
        **@context
      )

      assert_kind_of Hash, result
      assert_includes result, 'system_prompt'
      assert_includes result, 'user_prompt'

      # Verify character details are included
      assert_includes result['user_prompt'], @context['name']
      assert_includes result['user_prompt'], @context['class']
      assert_includes result['user_prompt'], @context['race']
      assert_includes result['user_prompt'], @context['alignment']

      # Verify traits are included
      @context['traits'].each do |trait|
        assert_includes result['user_prompt'], trait
      end
    end

    test 'raises error for missing template' do
      assert_raises(PromptService::TemplateNotFoundError) do
        PromptService.generate(
          request_type: 'nonexistent_template',
          provider: @provider
        )
      end
    end

    test 'validates required template keys' do
      assert_raises(PromptService::ValidationError) do
        # Create a temporary invalid template file
        template_path = Rails.root.join('config', 'prompts', 'default', 'invalid_template.yml')
        File.write(template_path, { 'metadata' => { 'version' => '1.0' } }.to_yaml)

        begin
          PromptService.generate(
            request_type: 'invalid_template',
            provider: @provider
          )
        ensure
          File.delete(template_path)
        end
      end
    end

    test 'caches template loading' do
      # First call should load from disk
      first_result = PromptService.generate(
        request_type: @request_type,
        provider: @provider,
        **@context
      )

      # Modify the template file
      template_path = Rails.root.join('config', 'prompts', 'default', "#{@request_type}.yml")
      original_content = File.read(template_path)
      
      # Create a modified version with a different description
      modified_content = original_content.sub(
        '"Template for generating D&D character backgrounds"',
        '"Modified template description"'
      )

      begin
        File.write(template_path, modified_content)

        # Second call should use cached version
        second_result = PromptService.generate(
          request_type: @request_type,
          provider: @provider,
          **@context
        )

        # Verify the cache is working by comparing the full results
        assert_equal first_result, second_result

        # Verify we're actually modifying the file
        template = YAML.load_file(template_path)
        assert_equal 'Modified template description', template['metadata']['description']
      ensure
        # Restore original content
        File.write(template_path, original_content)
      end
    end

    test 'handles empty context' do
      result = PromptService.generate(
        request_type: @request_type,
        provider: @provider
      )

      assert_kind_of Hash, result
      assert_includes result, 'system_prompt'
      assert_includes result, 'user_prompt'
    end

    test 'respects provider-specific templates' do
      # Create a provider-specific template
      provider_template_path = Rails.root.join('config', 'prompts', 'anthropic', "#{@request_type}.yml")
      provider_content = {
        'system_prompt' => 'Provider specific prompt',
        'user_prompt' => 'Provider specific user prompt for {{race}}'
      }.to_yaml

      begin
        FileUtils.mkdir_p(File.dirname(provider_template_path))
        File.write(provider_template_path, provider_content)

        result = PromptService.generate(
          request_type: @request_type,
          provider: @provider,
          **@context
        )

        assert_equal 'Provider specific prompt', result['system_prompt']
        assert_equal 'Provider specific user prompt for Half-Elf', result['user_prompt']
      ensure
        File.delete(provider_template_path) if File.exist?(provider_template_path)
      end
    end

    test 'generates prompt compatible with Character model structure' do
      # Generate the prompt
      prompt = PromptService.generate(
        request_type: @request_type,
        provider: @provider,
        **@context
      )

      # Verify prompt structure
      assert_kind_of Hash, prompt
      assert_includes prompt, 'system_prompt'
      assert_includes prompt, 'user_prompt'

      # Create a mock provider and get a response
      provider = Providers::Mock.new({})
      response = provider.chat(
        messages: [
          { 'role' => 'system', 'content' => prompt['system_prompt'] },
          { 'role' => 'user', 'content' => prompt['user_prompt'] }
        ]
      )

      # Verify response matches our model's expectations
      assert_kind_of Hash, response
      assert_includes response, 'background'
      assert_includes response, 'personality_traits'

      # Verify background is a string that can be stored in ActionText
      assert_kind_of String, response['background']
      assert response['background'].present?

      # Verify personality_traits is an array that can be stored in jsonb
      assert_kind_of Array, response['personality_traits']
      assert response['personality_traits'].length.between?(2, 4)
      response['personality_traits'].each do |trait|
        assert_kind_of String, trait
        assert trait.present?
      end

      # Verify the response can be stored in our Character model
      character = Character.new(
        name: @context['name'],
        class_type: @context['class'],
        alignment: @context['alignment'],
        level: 1
      )
      
      assert character.update(
        background: response['background'],
        personality_traits: response['personality_traits']
      )
      assert character.valid?
    end

    test 'generates compatible output from both providers' do
      # Test both providers to ensure consistent output structure
      [:anthropic, :openai].each do |provider|
        prompt = PromptService.generate(
          request_type: @request_type,
          provider: provider,
          **@context
        )

        # Verify provider-specific prompt structure
        case provider
        when :anthropic
          assert_includes prompt['system_prompt'], '<system>'
          assert_includes prompt['system_prompt'], '<rules>'
          assert_includes prompt['system_prompt'], '<output_format>'
        when :openai
          refute_includes prompt['system_prompt'], '<system>'
          assert_includes prompt['system_prompt'], 'Guidelines for creating the background:'
        end

        # Create a mock provider and get a response
        mock_provider = Providers::Mock.new({})
        response = mock_provider.chat(
          messages: [
            { 'role' => 'system', 'content' => prompt['system_prompt'] },
            { 'role' => 'user', 'content' => prompt['user_prompt'] }
          ]
        )

        # Verify response structure is consistent across providers
        assert_kind_of Hash, response
        assert_includes response, 'background'
        assert_includes response, 'personality_traits'
        assert_kind_of String, response['background']
        assert_kind_of Array, response['personality_traits']
        assert response['personality_traits'].length.between?(2, 4)
      end
    end

    test 'handles empty or missing context values' do
      # Test with minimal context
      minimal_context = {
        'name' => 'Test Character',
        'class' => 'Fighter',
        'alignment' => 'Lawful Good'
      }

      prompt = PromptService.generate(
        request_type: @request_type,
        provider: @provider,
        **minimal_context
      )

      # Verify prompt still generates correctly
      assert_kind_of Hash, prompt
      assert_includes prompt, 'system_prompt'
      assert_includes prompt, 'user_prompt'

      # Verify optional sections are handled gracefully
      refute_includes prompt['user_prompt'], '{{#traits}}'
      refute_includes prompt['user_prompt'], '{{#background_hooks}}'
      refute_includes prompt['user_prompt'], '{{#optional_context}}'
    end
  end
end 