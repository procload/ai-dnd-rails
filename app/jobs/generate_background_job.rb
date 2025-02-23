class GenerateBackgroundJob < ApplicationJob
  queue_as :default

  def perform(character_id, messages:, system_prompt:)
    character = Character.find(character_id)
    
    # Use MockLlmService for now, will be replaced with real LLM service later
    result = MockLlmService.generate_background(character)
    
    # Update character with generated content
    character.update!(background: result[:background])

    # Broadcast updates to all connected clients
    Turbo::StreamsChannel.broadcast_replace_to(
      "character_#{character_id}",
      target: "character_sheet",
      partial: "characters/sheet",
      locals: { character: character }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      "character_#{character_id}",
      target: "background_section",
      partial: "characters/background",
      locals: { character: character }
    )
  end
end 