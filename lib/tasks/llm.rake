# frozen_string_literal: true

namespace :llm do
  desc 'Test LLM providers with character background generation'
  task test_providers: :environment do
    test_character = {
      'name' => 'Thalia Stormwind',
      'class' => 'Bard',
      'race' => 'Half-Elf',
      'alignment' => 'Chaotic Good',
      'traits' => ['Musician', 'Wanderer', 'Curious']
    }

    [:anthropic, :openai].each do |provider|
      puts "\n=== Testing #{provider.to_s.titleize} Provider ===\n\n"

      begin
        # Generate the prompt
        prompt = Llm::PromptService.generate(
          request_type: 'character_background',
          provider: provider,
          **test_character
        )

        puts "Generated Prompt:"
        puts "----------------"
        puts "System Prompt:"
        puts prompt['system_prompt']
        puts "\nUser Prompt:"
        puts prompt['user_prompt']

        # Create the provider instance
        config = Rails.configuration.llm.providers[provider]
        puts "\nProvider Config:"
        puts "---------------"
        puts "Model: #{config[:model]}"
        puts "API Key Present: #{!config[:api_key].nil?}"
        puts "Max Tokens: #{config[:max_tokens]}"
        puts "Temperature: #{config[:temperature]}"

        provider_class = case provider
                        when :anthropic then Llm::Providers::Anthropic
                        when :openai then Llm::Providers::Openai
                        end
        llm = provider_class.new(config)

        # Test the connection
        puts "\nTesting Connection..."
        begin
          Rails.logger = Logger.new(STDOUT)
          Rails.logger.level = :debug
          if llm.test_connection
            puts "✅ Connection successful"
          else
            puts "❌ Connection failed"
            next
          end
        rescue StandardError => e
          puts "❌ Connection failed with error: #{e.message}"
          puts "Error backtrace:"
          e.backtrace.take(5).each { |line| puts "  #{line}" }
          next
        end

        # Make the request
        puts "\nGenerating Character Background..."
        response = llm.chat(
          messages: [
            { 'role' => 'system', 'content' => prompt['system_prompt'] },
            { 'role' => 'user', 'content' => prompt['user_prompt'] }
          ]
        )

        # Display the results
        puts "\nGenerated Background:"
        puts "-------------------"
        puts response['background']
        puts "\nPersonality Traits:"
        puts "------------------"
        response['personality_traits'].each do |trait|
          puts "- #{trait}"
        end

        # Validate the response
        puts "\nValidating Response..."
        word_count = response['background'].split.size
        puts "Word Count: #{word_count} (Target: 300-500)"
        puts "Paragraph Count: #{response['background'].split("\n\n").size} (Target: 4)"
        puts "Trait Count: #{response['personality_traits'].size} (Target: 2-4)"

      rescue StandardError => e
        puts "❌ Error testing #{provider}: #{e.message}"
        puts e.backtrace.take(5)
      end
    end
  end

  namespace :prompt do
    desc 'List all available prompt templates'
    task list: :environment do
      puts "\n=== Available Prompt Templates ===\n\n"

      Dir.glob(Rails.root.join('config/prompts/**/*.yml')).each do |path|
        relative_path = Pathname.new(path).relative_path_from(Rails.root)
        template = YAML.load_file(path)
        
        puts "Template: #{relative_path}"
        puts "Description: #{template.dig('metadata', 'description')}"
        puts "Version: #{template.dig('metadata', 'version')}"
        puts "Last Updated: #{template.dig('metadata', 'last_updated')}"
        puts
      end
    end

    desc 'Test a specific prompt template'
    task :test, [:request_type, :provider] => :environment do |_, args|
      request_type = args[:request_type] || 'character_background'
      provider = (args[:provider] || 'anthropic').to_sym

      puts "\n=== Testing Prompt Template: #{request_type} (#{provider}) ===\n\n"

      test_character = {
        'name' => 'Thalia Stormwind',
        'class' => 'Bard',
        'race' => 'Half-Elf',
        'alignment' => 'Chaotic Good',
        'traits' => ['Musician', 'Wanderer', 'Curious']
      }

      begin
        # Generate the prompt
        prompt = Llm::PromptService.generate(
          request_type: request_type,
          provider: provider,
          **test_character
        )

        puts "Generated Prompt:"
        puts "----------------"
        puts "System Prompt:"
        puts prompt['system_prompt']
        puts "\nUser Prompt:"
        puts prompt['user_prompt']

        # Load the template for validation
        template_path = Rails.root.join('config/prompts', provider.to_s, "#{request_type}.yml")
        template = YAML.load_file(template_path)

        puts "\nTemplate Validation:"
        puts "------------------"
        puts "✓ Has metadata" if template['metadata'].is_a?(Hash)
        puts "✓ Has configuration" if template['configuration'].is_a?(Hash)
        puts "✓ Has schema" if template['schema'].is_a?(Hash)
        puts "✓ Has system prompt" if template['system_prompt'].is_a?(String)
        puts "✓ Has user prompt" if template['user_prompt'].is_a?(String)

        # Validate schema
        schema = template['schema']
        if schema
          puts "\nSchema Validation:"
          puts "-----------------"
          puts "Required Fields: #{schema['required'].join(', ')}"
          schema['properties'].each do |field, props|
            puts "#{field}:"
            puts "  Type: #{props['type']}"
            puts "  Description: #{props['description']}"
            if props['items']
              puts "  Items:"
              puts "    Type: #{props['items']['type']}"
              puts "    Min Items: #{props['minItems']}"
              puts "    Max Items: #{props['maxItems']}"
            end
          end
        end

      rescue StandardError => e
        puts "❌ Error testing prompt: #{e.message}"
        puts e.backtrace.take(5)
      end
    end

    desc 'Compare provider responses'
    task compare: :environment do
      test_character = {
        'name' => 'Thalia Stormwind',
        'class' => 'Bard',
        'race' => 'Half-Elf',
        'alignment' => 'Chaotic Good',
        'traits' => ['Musician', 'Wanderer', 'Curious']
      }

      results = {}

      [:anthropic, :openai].each do |provider|
        puts "\n=== Testing #{provider.to_s.titleize} Provider ===\n\n"

        begin
          prompt = Llm::PromptService.generate(
            request_type: 'character_background',
            provider: provider,
            **test_character
          )

          config = Rails.configuration.llm.providers[provider]
          provider_class = case provider
                          when :anthropic then Llm::Providers::Anthropic
                          when :openai then Llm::Providers::Openai
                          end
          llm = provider_class.new(config)

          response = llm.chat(
            messages: [
              { 'role' => 'system', 'content' => prompt['system_prompt'] },
              { 'role' => 'user', 'content' => prompt['user_prompt'] }
            ]
          )

          results[provider] = {
            word_count: response['background'].split.size,
            paragraph_count: response['background'].split("\n\n").size,
            trait_count: response['personality_traits'].size,
            response: response
          }

        rescue StandardError => e
          puts "❌ Error with #{provider}: #{e.message}"
          next
        end
      end

      puts "\n=== Comparison Results ===\n\n"

      results.each do |provider, data|
        puts "#{provider.to_s.titleize}:"
        puts "----------------"
        puts "Word Count: #{data[:word_count]} (Target: 300-500)"
        puts "Paragraph Count: #{data[:paragraph_count]} (Target: 4)"
        puts "Trait Count: #{data[:trait_count]} (Target: 2-4)"
        puts "\nBackground Preview (first 100 words):"
        puts data[:response]['background'].split[0...100].join(' ') + "..."
        puts "\nPersonality Traits:"
        data[:response]['personality_traits'].each { |trait| puts "- #{trait}" }
        puts "\n"
      end
    end
  end
end 