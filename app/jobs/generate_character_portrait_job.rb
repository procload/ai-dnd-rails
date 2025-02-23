class GenerateCharacterPortraitJob < ApplicationJob
  queue_as :portraits

  retry_on ImageGeneration::ProviderError, wait: :exponentially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(character_id, prompt_type = :portrait)
    character = Character.find(character_id)
    
    Rails.logger.info "[GenerateCharacterPortraitJob] Starting portrait generation for character #{character.id}"
    
    # Generate the image
    result = ImageGeneration::Service.generate(
      character: character,
      prompt_type: prompt_type
    )
    
    Rails.logger.info "[GenerateCharacterPortraitJob] Portrait generation completed for character #{character.id}"
    
    # Broadcast the result to any listening clients
    broadcast_result(character, result)
  rescue StandardError => e
    Rails.logger.error "[GenerateCharacterPortraitJob] Failed to generate portrait: #{e.class} - #{e.message}"
    character&.update(image_status: :pending)
    raise
  end

  private

  def broadcast_result(character, result)
    Turbo::StreamsChannel.broadcast_replace_to(
      "character_#{character.id}",
      target: "character_portrait",
      partial: "characters/portrait",
      locals: { character: character }
    )
  end
end 