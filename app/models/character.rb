# frozen_string_literal: true

class Character < ApplicationRecord
  # Game constants defined at the class level for easy reference and validation
  CLASSES = %w[Barbarian Bard Cleric Druid Fighter Monk Paladin Ranger Rogue Sorcerer Warlock Wizard].freeze
  ALIGNMENTS = ['Lawful Good', 'Neutral Good', 'Chaotic Good', 'Lawful Neutral', 'True Neutral', 'Chaotic Neutral', 'Lawful Evil', 'Neutral Evil', 'Chaotic Evil'].freeze
  ABILITIES = %w[strength dexterity constitution intelligence wisdom charisma].freeze
  CLASS_HIT_DICE = {
    'Barbarian' => 12, 'Fighter' => 10, 'Paladin' => 10, 'Ranger' => 10,
    'Wizard' => 6, 'Sorcerer' => 6,
    'Bard' => 8, 'Cleric' => 8, 'Druid' => 8, 'Monk' => 8, 'Rogue' => 8, 'Warlock' => 8
  }.freeze
  RACES = %w[Dragonborn Dwarf Elf Gnome Half-Elf Half-Orc Halfling Human Tiefling].freeze

  # Active Storage configuration
  has_many :character_portraits, dependent: :destroy
  has_one :selected_portrait, -> { selected }, class_name: 'CharacterPortrait'
  has_one_attached :profile_image do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 100]
    attachable.variant :medium, resize_to_limit: [300, 300]
  end

  # Rich text support
  has_rich_text :background

  # Image status tracking
  enum :image_status, { pending: 0, generating: 1, completed: 2 }, prefix: true

  # JSON fields with default empty values
  attribute :ability_scores, :jsonb, default: {}
  attribute :personality_traits, :string, array: true
  attribute :equipment, :jsonb, default: { weapons: [], armor: [], adventuring_gear: [] }
  attribute :spells, :jsonb, default: { cantrips: [], level_1_spells: [] }
  attribute :image_metadata, :jsonb, default: {}
  attribute :personality_details, :jsonb, default: { ideals: [], bonds: [], flaws: [] }
  attribute :character_values, :jsonb, default: { ideals: [], bonds: [], flaws: [] }

  # Character trait and value validations
  validates :character_values, presence: true, allow_blank: true

  # Rails validations provide automatic data integrity checks
  validates :name, presence: true
  validates :level, numericality: { in: 1..20 }
  validates :class_type, inclusion: { in: CLASSES, message: "must be a valid class" }
  validates :alignment, inclusion: { in: ALIGNMENTS, message: "must be a valid alignment" }
  validates :race, inclusion: { in: RACES, message: "must be a valid race" }

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

  def spellcaster?
    case class_type
    when 'Wizard', 'Sorcerer', 'Warlock'
      true
    when 'Bard', 'Cleric', 'Druid', 'Paladin', 'Ranger'
      true
    else
      false
    end
  end

  # Portrait generation
  def generate_portrait
    Rails.logger.debug "[Character] Starting portrait generation"
    
    # Use the ImageGeneration service directly
    result = ImageGeneration::Service.generate(character: self)
    Rails.logger.debug "[Character] Image generation result: #{result.inspect}"
    
    # The service handles portrait creation and attachment
    result
  rescue StandardError => e
    Rails.logger.error "[Character] Failed to generate portrait: #{e.message}"
    Rails.logger.error "[Character] Error class: #{e.class}"
    Rails.logger.error "[Character] Backtrace:\n#{e.backtrace.join("\n")}"
    raise ImageGeneration::Error, "Failed to generate portrait: #{e.message}"
  end

  # Portrait management
  def current_portrait
    selected_portrait || character_portraits.most_recent_first.first
  end

  def select_portrait(portrait)
    return unless portrait.character_id == id
    
    Character.transaction do
      # First, unselect all portraits for this character
      character_portraits.update_all(selected: false)
      # Then select the new portrait
      portrait.update!(selected: true)
    end
  end

  # AI-powered generation methods
  def generate_background
    prompt = Llm::PromptService.generate(
      request_type: 'character_background',
      provider: Rails.configuration.llm.provider,
      name: name,
      race: race,
      class: class_type,
      level: level,
      alignment: alignment,
      character_traits: personality_traits
    )

    response = Llm::Service.chat_with_schema(
      messages: [{ 'role' => 'user', 'content' => prompt['user_prompt'] }],
      system_prompt: prompt['system_prompt'],
      schema: prompt['schema']
    )

    # Create a rich text content combining all sections
    content = ApplicationController.render(
      template: 'characters/_background_content',
      layout: false,
      locals: {
        early_life: response['early_life'],
        pivotal_moments: response['pivotal_moments'],
        recent_history: response['recent_history'],
        unresolved_mysteries: response['unresolved_mysteries']
      }
    )

    self.background = content
    save!(validate: false)
  rescue StandardError => e
    Rails.logger.error("Failed to generate background: #{e.message}")
    raise Llm::Service::ProviderError, "Failed to generate background: #{e.message}"
  end

  def generate_personality_details
    prompt = Llm::PromptService.generate(
      request_type: 'character_personality_details',
      provider: Rails.configuration.llm.provider,
      name: name,
      race: race,
      class: class_type,
      level: level,
      alignment: alignment,
      background: background.to_plain_text,
      personality_traits: personality_traits
    )

    response = Llm::Service.chat_with_schema(
      messages: [{ 'role' => 'user', 'content' => prompt['user_prompt'] }],
      system_prompt: prompt['system_prompt'],
      schema: prompt['schema']
    )

    self.personality_details = response['personality_details']
    save!(validate: false)
  rescue StandardError => e
    Rails.logger.error("Failed to generate personality details: #{e.message}")
    raise Llm::Service::ProviderError, "Failed to generate personality details: #{e.message}"
  end

  def generate_traits
    prompt = Llm::PromptService.generate(
      request_type: 'character_traits',
      provider: Rails.configuration.llm.provider,
      name: name,
      race: race,
      class_type: class_type,
      level: level,
      alignment: alignment,
      background: background
    )

    response = Llm::Service.chat_with_schema(
      messages: [{ 'role' => 'user', 'content' => prompt['user_prompt'] }],
      system_prompt: prompt['system_prompt'],
      schema: prompt['schema']
    )

    # First, let's log what we're about to save
    Rails.logger.debug "[Character] Traits from LLM: #{response['traits'].inspect}"
    
    # Transform and save to personality_traits
    self.personality_traits = response['traits'].map { |t| "#{t['trait']}: #{t['description']}" }
    save!(validate: false)
    
    # Log the actual saved personality_traits
    Rails.logger.debug "[Character] Saved personality_traits: #{personality_traits.inspect}"
    
    # Return the saved traits
    personality_traits
  rescue StandardError => e
    Rails.logger.error("[Character] Failed to generate traits: #{e.message}")
    raise Llm::Service::ProviderError, "Failed to generate traits: #{e.message}"
  end

  def generate_character_values
    prompt = Llm::PromptService.generate(
      request_type: 'character_values',
      provider: Rails.configuration.llm.provider,
      name: name,
      race: race,
      class: class_type,
      level: level,
      alignment: alignment,
      background: background.to_plain_text
    )

    response = Llm::Service.chat_with_schema(
      messages: [{ 'role' => 'user', 'content' => prompt['user_prompt'] }],
      system_prompt: prompt['system_prompt'],
      schema: prompt['schema']
    )

    self.character_values = response
    save!(validate: false)
  rescue StandardError => e
    Rails.logger.error("Failed to generate character values: #{e.message}")
    raise Llm::Service::ProviderError, "Failed to generate character values: #{e.message}"
  end

  def generate_equipment_suggestions
    prompt = Llm::PromptService.generate(
      request_type: 'suggest_equipment',
      provider: Rails.configuration.llm.provider,
      name: name,
      race: race,
      class: class_type,
      level: level,
      alignment: alignment,
      background: background.to_plain_text,
      current_equipment: equipment.values.flatten.map { |item| item.is_a?(Hash) ? item['name'] : item }
    )

    response = Llm::Service.chat_with_schema(
      messages: [{ 'role' => 'user', 'content' => prompt['user_prompt'] }],
      system_prompt: prompt['system_prompt'],
      schema: prompt['schema']
    )

    self.equipment = response
    save!(validate: false)
  rescue StandardError => e
    Rails.logger.error("Failed to generate equipment suggestions: #{e.message}")
    raise Llm::Service::ProviderError, "Failed to generate equipment suggestions: #{e.message}"
  end

  def generate_spell_suggestions
    return unless spellcaster?

    prompt = Llm::PromptService.generate(
      request_type: 'suggest_spells',
      provider: Rails.configuration.llm.provider,
      name: name,
      class: class_type,
      level: level
    )

    response = Llm::Service.chat_with_schema(
      messages: [{ 'role' => 'user', 'content' => prompt['user_prompt'] }],
      system_prompt: prompt['system_prompt'],
      schema: prompt['schema']
    )

    self.spells = response
    save!(validate: false)
  rescue StandardError => e
    Rails.logger.error("Failed to generate spell suggestions: #{e.message}")
    raise Llm::Service::ProviderError, "Failed to generate spell suggestions: #{e.message}"
  end

  private

  def set_default_values
    self.level ||= 1
    self.ability_scores ||= {}
    self.equipment ||= { 'weapons' => [], 'armor' => [], 'adventuring_gear' => [] }
    self.spells ||= { 'cantrips' => [], 'level_1_spells' => [] }
    self.character_values ||= { 'ideals' => [], 'bonds' => [], 'flaws' => [] }
  end

  def ensure_arrays_initialized
    self.equipment ||= { 'weapons' => [], 'armor' => [], 'adventuring_gear' => [] }
    self.spells ||= { 'cantrips' => [], 'level_1_spells' => [] }
    self.character_values ||= { 'ideals' => [], 'bonds' => [], 'flaws' => [] }
  end
end 