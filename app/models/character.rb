class Character < ApplicationRecord
  # Game constants defined at the class level for easy reference and validation
  CLASSES = %w[Barbarian Bard Cleric Druid Fighter Monk Paladin Ranger Rogue Sorcerer Warlock Wizard].freeze
  ALIGNMENTS = ['Lawful Good', 'Neutral Good', 'Chaotic Good', 'Lawful Neutral', 'True Neutral', 'Chaotic Neutral', 'Lawful Evil', 'Neutral Evil', 'Chaotic Evil'].freeze
  ABILITIES = %w[strength dexterity constitution intelligence wisdom charisma].freeze
  CLASS_HIT_DICE = {'Barbarian' => 12, 'Fighter' => 10, 'Paladin' => 10, 'Ranger' => 10, 'Wizard' => 6, 'Sorcerer' => 6, 'Bard' => 8, 'Cleric' => 8, 'Druid' => 8, 'Monk' => 8, 'Rogue' => 8, 'Warlock' => 8}.freeze

  # Rails validations provide automatic data integrity checks
  validates :name, presence: true
  validates :level, numericality: { in: 1..20 }
  validates :class_type, inclusion: { in: CLASSES, message: "must be a valid class" }
  validates :alignment, inclusion: { in: ALIGNMENTS, message: "must be a valid alignment" }

  # Enables rich text editing for character backgrounds
  has_rich_text :background

  # Game mechanics expressed as clear, focused methods
  def proficiency_bonus
    ((level - 1) / 4) + 2
  end

  def ability_modifier(ability)
    score = ability_scores[ability.to_s]
    (score - 10) / 2
  end

  # Complex game rules broken down into readable Ruby code
  def armor_class
    base = equipment.find { |item| item['type'] == 'armor' }&.dig('ac') || 10
    base + ability_modifier(:dexterity)
  end

  def hit_points
    hit_die = CLASS_HIT_DICE[class_type]
    base = hit_die + ability_modifier(:constitution)
    base + ((level - 1) * (hit_die / 2 + 1))
  end

  def generate_background
    # Offload LLM processing to a background job to keep the UI responsive
    GenerateBackgroundJob.perform_later(
      id,
      messages: character_prompt,
      system_prompt: background_guidelines
    )
  end

  private

  # Simple, focused prompt generation for the LLM
  def character_prompt
    "Create a compelling backstory for #{name}, a level #{level} #{class_type} with #{alignment} alignment."
  end
end
