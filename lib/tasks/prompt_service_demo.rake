# frozen_string_literal: true

namespace :prompt do
  desc 'Demonstrate PromptService usage with character background generation'
  task demo: :environment do
    # Example context for a character
    context = {
      'alignment' => 'Chaotic Good',
      'race' => 'Half-Elf',
      'class' => 'Bard',
      'traits' => ['Musician', 'Traveler']
    }

    puts "\n=== Generating Character Background Prompt ===\n\n"

    # Generate the prompt
    prompt = Llm::PromptService.generate(
      request_type: 'character_background',
      provider: :anthropic,
      **context
    )

    puts "System Prompt:"
    puts "-------------"
    puts prompt['system_prompt']
    puts "\nUser Prompt:"
    puts "------------"
    puts prompt['user_prompt']

    puts "\n=== Testing with Mock Provider ===\n\n"

    # Create a mock provider and test the prompt
    provider = Llm::Providers::Mock.new({})
    response = provider.chat(
      messages: [
        { 'role' => 'system', 'content' => prompt['system_prompt'] },
        { 'role' => 'user', 'content' => prompt['user_prompt'] }
      ]
    )

    puts "\nGenerated Background:"
    puts "-------------------"
    puts response['background']
    puts "\nPersonality Traits:"
    puts "------------------"
    response['personality_traits'].each do |trait|
      puts "- #{trait}"
    end
  end

  desc 'List available prompt templates'
  task list: :environment do
    puts "\n=== Available Prompt Templates ===\n\n"

    # List templates in each provider directory
    Dir.glob(Rails.root.join('config/prompts/*/*.yml')).each do |path|
      relative_path = Pathname.new(path).relative_path_from(Rails.root)
      template = YAML.load_file(path)
      
      puts "Template: #{relative_path}"
      puts "Description: #{template.dig('metadata', 'description')}"
      puts "Version: #{template.dig('metadata', 'version')}"
      puts "Last Updated: #{template.dig('metadata', 'last_updated')}"
      puts
    end
  end
end 