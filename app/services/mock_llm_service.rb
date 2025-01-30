# frozen_string_literal: true

# Service for generating mock D&D character data
class MockLlmService
  class << self
    def generate_background(character)
      data = load_json('background.json')
      
      # Get all backgrounds since they're all generic now
      matches = data['backgrounds']
      Rails.logger.debug "Found #{matches.length} available backgrounds"
      
      return default_background(character) if matches.empty?

      # Randomly select from all backgrounds
      match = matches.sample
      Rails.logger.debug "Selected background: #{match['background'][0..100]}..."
      Rails.logger.debug "Selected personality traits: #{match['personality_traits'].inspect}"

      {
        background: match['background'],
        personality_traits: match['personality_traits']
      }
    end

    def suggest_equipment(character)
      data = load_json('equipment.json')
      match = data['equipment_suggestions'].find do |eq|
        eq['class_type'] == character.class_type &&
        eq['level'] == character.level
      end

      match ? match['equipment'] : []
    end

    def suggest_spells(character)
      data = load_json('spells.json')
      match = data['spell_suggestions'].find do |sp|
        sp['class_type'] == character.class_type &&
        sp['level'] == character.level
      end

      return {} unless match

      {
        cantrips: match['cantrips'],
        level_1_spells: match['level_1_spells']
      }
    end

    private

    def load_json(filename)
      file_path = Rails.root.join('mock', 'responses', filename)
      JSON.parse(File.read(file_path))
    rescue JSON::ParserError, Errno::ENOENT => e
      Rails.logger.error "Error loading mock data: #{e.message}"
      {}
    end

    def default_background(character)
      {
        background: "A mysterious #{character.class_type} with an untold story...",
        personality_traits: [
          "Keeps to themselves",
          "Values actions over words"
        ]
      }
    end

    def find_background_matches(backgrounds, class_type, alignment)
      backgrounds.select do |bg|
        bg['class_type'] == class_type &&
        bg['alignment'] == alignment
      end
    end
  end
end 