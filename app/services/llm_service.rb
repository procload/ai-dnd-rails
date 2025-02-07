class LlmService
  class << self
    def generate_background(character)
      messages = [
        {
          'role' => 'user',
          'content' => "Generate a background for a level #{character.level} #{character.alignment} #{character.class_type} named #{character.name}"
        }
      ]

      # Get the prompt from our PromptService
      prompt = Llm::PromptService.generate(
        request_type: 'character_background',
        provider: Rails.configuration.llm.provider,
        name: character.name,
        class: character.class_type,
        alignment: character.alignment,
        level: character.level
      )

      # Send the request to our LLM service
      response = Llm::Service.chat(
        messages: messages,
        system_prompt: prompt['system_prompt']
      )

      {
        background: response['background'],
        personality_traits: response['personality_traits']
      }
    end

    def suggest_equipment(character)
      messages = [
        {
          'role' => 'user',
          'content' => "Suggest equipment for a level #{character.level} #{character.alignment} #{character.class_type}"
        }
      ]

      prompt = Llm::PromptService.generate(
        request_type: 'suggest_equipment',
        provider: Rails.configuration.llm.provider,
        class: character.class_type,
        level: character.level
      )

      response = Llm::Service.chat(
        messages: messages,
        system_prompt: prompt['system_prompt']
      )

      response
    end

    def suggest_spells(character)
      return {} unless ['Wizard', 'Sorcerer', 'Warlock', 'Bard', 'Cleric', 'Druid'].include?(character.class_type)

      messages = [
        {
          'role' => 'user',
          'content' => "Suggest spells for a level #{character.level} #{character.class_type}"
        }
      ]

      prompt = Llm::PromptService.generate(
        request_type: 'suggest_spells',
        provider: Rails.configuration.llm.provider,
        class: character.class_type,
        level: character.level
      )

      response = Llm::Service.chat(
        messages: messages,
        system_prompt: prompt['system_prompt']
      )

      response
    end
  end
end 