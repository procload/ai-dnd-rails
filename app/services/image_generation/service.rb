module ImageGeneration
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ProviderError < Error; end
  class ImageGenerationError < Error; end

  class Service
    require 'open-uri'
    require 'active_storage'
    require_relative 'errors'

    attr_reader :character, :prompt_type

    CLASS_DETAILS = {
      'Wizard' => ['magical energy surrounding their hands', 'arcane symbols floating nearby', 'glowing spell effects'],
      'Fighter' => ['battle-worn armor details', 'warrior\'s confident stance', 'combat-ready appearance'],
      'Rogue' => ['shadowy elements around them', 'cunning expression', 'stealthy attire'],
      'Cleric' => ['holy symbols', 'divine light effects', 'religious vestments'],
      'Paladin' => ['righteous aura', 'noble bearing', 'holy armor details'],
      'Druid' => ['natural elements', 'wild energy effects', 'organic accessories'],
      'Bard' => ['musical instrument details', 'charismatic expression', 'artistic flair'],
      'Barbarian' => ['primal energy effects', 'fierce expression', 'tribal elements'],
      'Monk' => ['serene focus', 'martial arts stance', 'spiritual energy'],
      'Ranger' => ['wilderness gear details', 'keen-eyed expression', 'natural camouflage elements'],
      'Sorcerer' => ['innate magical aura', 'wild energy effects', 'mystical presence'],
      'Warlock' => ['eldritch energy effects', 'otherworldly elements', 'subtle patron influences']
    }.freeze

    def initialize(character:, prompt_type: 'portrait')
      @character = character
      @prompt_type = prompt_type
      logger.info "Initializing image generation for character: #{character.name} (ID: #{character.id})"
    end

    def self.generate(character:)
      new(character: character).generate
    end

    def generate
      logger.info "[ImageGeneration::Service] Generating portrait for character #{character.id}"
      
      validate_character!
      
      # Get the prompt from PromptService
      prompt = Llm::PromptService.generate(
        request_type: 'character_image',
        provider: provider_name,
        **character_details
      )
      
      logger.debug "[ImageGeneration::Service] Using prompt: #{prompt}"
      
      # Call Fal.ai
      result = HTTP.auth("Key #{ENV['FAL_API_KEY']}")
                     .post("https://fal.run/fal-ai/recraft-v3",
                       json: {
                         prompt: prompt,
                         image_size: "portrait_4_3",
                         style: "realistic_image"
                       })
      
      response = JSON.parse(result.body.to_s)
      logger.debug "[ImageGeneration::Service] Got response: #{response.inspect}"
      
      if !result.status.success?
        raise Error, "Failed to generate image: #{response['error'] || response['detail']&.first&.dig('msg') || 'Unknown error'}"
      end
      
      # Unselect any existing selected portraits
      character.character_portraits.update_all(selected: false)
      
      # Create portrait record first
      portrait = character.character_portraits.new(
        selected: true,
        generation_prompt: prompt  # Store the actual prompt used
      )
      
      begin
        # Download and attach the image
        downloaded_image = URI.open(response['images'].first['url'])
        portrait.image.attach(
          io: downloaded_image,
          filename: "portrait_#{Time.current.to_i}.png",
          content_type: 'image/png'
        )
        
        # Save after attachment
        portrait.save!
        portrait
      rescue => e
        logger.error "[ImageGeneration::Service] Error saving portrait: #{e.message}"
        portrait.destroy if portrait.persisted?
        raise Error, "Failed to save portrait: #{e.message}"
      end
    end

    def generate_image(prompt, options = {})
      with_retries do
        begin
          provider.generate_image(prompt)
        rescue StandardError => e
          Rails.logger.error "[ImageGeneration::Service] Error generating image: #{e.class} - #{e.message}"
          raise ImageGenerationError, "Failed to generate image: #{e.message}"
        end
      end
    end

    private

    def logger
      Rails.logger
    end

    def provider
      @provider ||= ImageGeneration::Factory.create_provider
    end

    def provider_name
      Rails.configuration.image_generation.provider
    end

    def validate_character!
      missing_attributes = []
      missing_attributes << "race" if character.race.blank?
      missing_attributes << "class type" if character.class_type.blank?
      missing_attributes << "level" if character.level.blank?
      missing_attributes << "alignment" if character.alignment.blank?

      if missing_attributes.any?
        raise ImageGenerationError, "Cannot generate portrait: Missing required attributes: #{missing_attributes.join(', ')}"
      end
    end

    def character_details
      {
        name: character.name,
        race: character.race || "Unknown Race",
        class_type: character.class_type,
        level: character.level,
        alignment: character.alignment,
        character_traits: (character.character_traits || []).map { |t| 
          t.is_a?(Hash) ? t : JSON.parse(t.to_s)
        },
        character_values: {
          ideals: (character.character_values&.dig('ideals') || []).map { |i|
            i.is_a?(Hash) ? i : JSON.parse(i.to_s)
          }
        },
        class_type_details: CLASS_DETAILS[character.class_type].join(", ")
      }
    end

    def attach_image(result, generation_prompt)
      logger.info "\n=== Image Generation Result ===\n" \
                  "Character: #{character.name} (ID: #{character.id})\n" \
                  "Status: #{result[:error].present? ? 'Error' : 'Success'}\n" \
                  "================================"

      if result[:error].present?
        logger.error "Provider returned error: #{result[:error]}"
        return result
      end

      begin
        logger.info "Starting image attachment process"
        
        downloaded_image = URI.open(result[:url])
        logger.debug "Successfully downloaded image"
        
        portrait = character.character_portraits.create!(
          generation_prompt: generation_prompt,
          metadata: result.except(:url).transform_keys(&:to_s),
          selected: true
        )
        logger.debug "Created portrait record: #{portrait.id}"
        
        portrait.image.attach(
          io: downloaded_image,
          filename: "#{character.id}_portrait_#{Time.current.to_i}.png",
          content_type: 'image/png'
        )
        logger.debug "Successfully attached image to portrait"

        character.profile_image.attach(
          io: URI.open(result[:url]),
          filename: "#{character.id}_portrait.png",
          content_type: 'image/png'
        )
        logger.debug "Successfully updated legacy profile_image"

        character.update!(image_status: :completed)

        {
          storage_url: Rails.application.routes.url_helpers.rails_blob_path(portrait.image, only_path: true),
          dall_e_url: result[:url],
          status: :success
        }
      rescue StandardError => e
        Rails.logger.error "[ImageGeneration::Service] Error attaching image: #{e.class} - #{e.message}"
        character.update!(image_status: :pending)
        raise ImageGenerationError, "Failed to attach image: #{e.message}"
      end
    end
  end
end 