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

  # Initialize default values for new records
  after_initialize :set_default_values, if: :new_record?
  before_save :ensure_arrays_initialized

  # Game mechanics expressed as clear, focused methods
  def proficiency_bonus
    ((level - 1) / 4) + 2
  end

  def ability_modifier(ability)
    scores = ability_scores || {}
    score = scores[ability.to_s].to_i
    (score - 10) / 2
  end

  # Complex game rules broken down into readable Ruby code
  def armor_class
    base = 10  # Default AC without armor
    equipment_hash = equipment || {}
    armor_items = equipment_hash['armor'] || []
    
    if armor = armor_items.first
      base = armor['ac'].to_i
    end
    
    base + ability_modifier(:dexterity)
  end

  def hit_points
    return 0 unless class_type.present?
    
    hit_die = CLASS_HIT_DICE[class_type]
    base = hit_die + ability_modifier(:constitution)
    level_bonus = ((level || 1) - 1) * ((hit_die / 2) + 1)
    base + level_bonus
  end

  def generate_background
    # Get the prompt from our PromptService
    prompt = Llm::PromptService.generate(
      request_type: 'character_background',
      provider: Rails.configuration.llm.provider,
      name: name,
      class: class_type,
      alignment: alignment,
      level: level
    )

    # Send the request to our LLM service
    response = Llm::Service.chat(
      messages: [
        {
          'role' => 'user',
          'content' => prompt['user_prompt']
        }
      ],
      system_prompt: prompt['system_prompt']
    )

    # Update with new content
    update!(
      background: response['background'],
      personality_traits: response['personality_traits']
    )
  end

  private

  def set_default_values
    self.ability_scores ||= ABILITIES.each_with_object({}) { |ability, scores| scores[ability] = 10 }
    
    # Initialize empty arrays for equipment and spells
    self.equipment = { 'weapons' => [], 'armor' => [], 'adventuring_gear' => [] }
    self.spells = { 'cantrips' => [], 'level_1_spells' => [] }
    self.personality_traits = []
  end

  def ensure_arrays_initialized
    self.personality_traits ||= []
    self.equipment ||= { 'weapons' => [], 'armor' => [], 'adventuring_gear' => [] }
    self.spells ||= { 'cantrips' => [], 'level_1_spells' => [] }
  end

  # Simple, focused prompt generation for the LLM
  def character_prompt
    "Create a compelling backstory for #{name}, a level #{level} #{class_type} with #{alignment} alignment."
  end

  def background_guidelines
    "Generate a character background that includes their origin, motivation, and key life events."
  end
end
