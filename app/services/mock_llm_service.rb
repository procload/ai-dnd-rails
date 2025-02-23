def self.generate_background(character)
  data = load_json('background.json')
  
  # Get all backgrounds since they're all generic now
  matches = data['backgrounds']
  Rails.logger.debug "Found #{matches.length} available backgrounds"
  
  return default_background(character) if matches.empty?

  # Randomly select from all backgrounds
  match = matches.sample
  Rails.logger.debug "Selected background: #{match['background'][0..100]}..."

  {
    background: match['background']
  }
end

def self.generate_traits(character)
  {
    traits: [
      {
        trait: "Curious Explorer",
        category: "social",
        description: "Always seeking to learn about new places and cultures"
      },
      {
        trait: "Quick-witted",
        category: "general",
        description: "Able to think and respond rapidly in any situation"
      },
      {
        trait: "Battle-hardened",
        category: "combat",
        description: "Years of combat have honed their instincts"
      }
    ]
  }
end

def self.generate_character_values(character)
  {
    ideals: [
      { ideal: "Knowledge", manifestation: "Seeks to understand the mysteries of the world" },
      { ideal: "Justice", manifestation: "Believes in fair treatment for all" }
    ],
    bonds: [
      { bond: "Family Legacy", manifestation: "Carries an ancient family heirloom" },
      { bond: "Mentor's Teaching", manifestation: "Follows the wisdom of their old master" }
    ],
    flaws: [
      { flaw: "Overconfident", manifestation: "Often underestimates challenges" },
      { flaw: "Stubborn", manifestation: "Refuses to change course once decided" }
    ]
  }
end

def self.suggest_equipment(character)
  {
    'weapons' => [
      { 'name' => 'Longsword', 'damage' => '1d8 slashing' },
      { 'name' => 'Shortbow', 'damage' => '1d6 piercing' }
    ],
    'armor' => [
      { 'name' => 'Chain Mail', 'ac' => 16 }
    ],
    'adventuring_gear' => [
      'Backpack',
      'Bedroll',
      'Rope, 50 feet',
      'Tinderbox',
      'Torches (10)'
    ]
  }
end

def self.suggest_spells(character)
  {
    'cantrips' => [
      { 'name' => 'Fire Bolt', 'school' => 'Evocation' },
      { 'name' => 'Mage Hand', 'school' => 'Conjuration' },
      { 'name' => 'Light', 'school' => 'Evocation' }
    ],
    'level_1_spells' => [
      { 'name' => 'Magic Missile', 'school' => 'Evocation' },
      { 'name' => 'Shield', 'school' => 'Abjuration' },
      { 'name' => 'Mage Armor', 'school' => 'Abjuration' }
    ]
  }
end

def self.generate_portrait(character)
  {
    'image_url' => 'https://placehold.co/600x800/png?text=Character+Portrait'
  }
end

private

def self.load_json(filename)
  file_path = Rails.root.join('mock', 'responses', filename)
  JSON.parse(File.read(file_path))
rescue JSON::ParserError, Errno::ENOENT => e
  Rails.logger.error "Error loading mock data: #{e.message}"
  {}
end

def self.default_background(character)
  {
    background: "A mysterious #{character.class_type} with an untold story..."
  }
end 