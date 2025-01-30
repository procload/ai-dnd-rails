# LinkedIn Posts:

"Boring" technology might be the future of AI applications.

Starting a series building a D&D character generator that challenges our industry's obsession with complexity. Rails - with its predictable conventions, server-rendered HTML, and focus on simplicity - is an excellent match for the generative AI era.

Rails' established patterns - server-rendered HTML, consistent conventions, and straightforward architecture - align well with the needs of generative AI applications. The framework's steady evolution and focus on simplicity offer some interesting advantages for LLM integration.

Part 1 examines how Rails' approach to web development might be particularly relevant in the AI era. While our industry often equates innovation with complexity, there's value in examining proven patterns through this new lens.

Following articles will explore Rails' service architecture for LLMs, real-time updates, and how convention over configuration applies to AI workflows.

[link]

#Rails #AI #WebDev #BoringTechnology

Unpopular opinion: The AI revolution doesn't need your JavaScript framework.

Kicking off a series exploring how "boring" technology might be the secret weapon for generative AI apps. We're building a D&D character generator with Rails because its conventions, server-rendered HTML, and battle-tested patterns are surprisingly perfect for the AI era.

Part 1 questions why we traded simple for complex right when AI streaming makes the server more relevant than ever. Rails' "boring" choices - consistent conventions, HTML over JSON, predictable file structure - turn out to be exactly what we need for LLM integration.

The tech industry keeps adding layers of complexity while Rails quietly evolves its proven foundations. Sometimes the best way forward is to question why we abandoned what worked.

Series will explore:

- Why Rails conventions are ideal for AI workflows
- How "boring" tech handles streaming better than SPAs
- Building real-time features without the complexity

[link]

#Rails #AI #WebDev #BoringTechnology

# Rails & AI: Building Our Character Generator

The tech industry has an interesting relationship with complexity. We often reach for intricate solutions when simpler ones might serve better. Modern web development exemplifies this tendency - layers of build tools, state management libraries, and framework abstractions that sometimes feel more like organizational theater than engineering solutions.

Ruby on Rails takes a different path. While other frameworks chase the latest architectural patterns, Rails has steadily evolved its server-rendered foundations. The framework's gradual incorporation of new features complements its core principles rather than replacing them.

The rise of AI-powered applications creates an opportunity to reconsider our approach to web development. Rails' convention over configuration philosophy makes it particularly well-suited for this new era. Clear, consistent rules create a solid foundation for building complex applications.

To explore this, we'll build a D&D character generator. The project will demonstrate how Rails simplifies AI integration while maintaining clean architecture.

## Leveraging AI for Development

Modern AI tools have transformed our implementation of complex domain rules. Tools like GitHub Copilot and Cursor understand Rails conventions deeply, helping developers generate and refine rule-based logic efficiently. While the industry chases ever more complex toolchains, Rails' consistency offers a refreshing counterpoint.

```ruby
# Calculate ability modifiers using D&D's standard formula
# This simple, pure function is easy for AI tools to understand and generate
def ability_modifier(ability)
  score = ability_scores[ability.to_s]
  (score - 10) / 2  # D&D's standard modifier calculation
end

# Complex game logic expressed clearly through Ruby's expressive syntax
# Shows how Rails encourages readable, maintainable business logic
def hit_points_at_level(level)
  return CLASS_HIT_DICE[class_type] + constitution_modifier if level == 1

  base_hp = CLASS_HIT_DICE[class_type] + constitution_modifier
  level_hp = (2..level).sum do
    (CLASS_HIT_DICE[class_type] / 2 + 1) + constitution_modifier
  end
  base_hp + level_hp
end
```

## Convention Over Configuration: The Rails Way

Rails provides a set of clear conventions that structure how we build applications. These conventions standardize common patterns, speed up development, and help maintain code quality. In a landscape where many frameworks emphasize ultimate flexibility, Rails' opinions about structure become a significant advantage.

Consider our character model. Its structure follows Rails conventions:

```ruby
# Required gems for Rails 8 features we'll use
gem 'activerecord-postgresql-adapter'  # Required for jsonb fields in Rails 8
gem 'actiontext'                       # Powers our rich text content

# Rails generator command that creates our database table and model
# Note how jsonb fields allow flexible JSON storage with PostgreSQL optimization
rails generate model Character \
  name:string \
  class_type:string \
  level:integer \
  background:text \     # Will be replaced by rich_text through ActionText
  alignment:string \
  ability_scores:jsonb \    # Flexible JSON storage for character stats
  personality_traits:jsonb \ # Structured data that can be AI-generated
  equipment:jsonb \         # Complex nested data structure
  spells:jsonb             # Spells can evolve without database changes
```

This generator creates a standardized model structure that both humans and LLMs can predict and understand. Rails' naming conventions and file organization mean AI tools can reliably locate and modify related files - models, controllers, views, and tests all have consistent locations and naming patterns.

The model implementation demonstrates how Rails conventions naturally express domain rules:

```ruby
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
    armor = (equipment || []).find { |item| item['type'] == 'armor' }
    base = armor['ac'] if armor
    base + ability_modifier(:dexterity)
  end

  def hit_points
    return 0 unless class_type.present?

    hit_die = CLASS_HIT_DICE[class_type]
    base = hit_die + ability_modifier(:constitution)
    level_bonus = ((level || 1) - 1) * ((hit_die / 2) + 1)
    base + level_bonus
  end

  private

  def set_default_values
    self.ability_scores ||= ABILITIES.each_with_object({}) { |ability, scores| scores[ability] = 10 }
    self.equipment ||= []
    self.personality_traits ||= []
    self.spells ||= []
  end
end
```

Rails conventions make this code particularly suitable for LLM-based workflows. The constants at the top of the file define clear boundaries for valid data. Validation rules express business logic in a declarative style that AI tools can easily understand and modify. Method names follow consistent patterns that make their purpose clear without excessive documentation.

The use of `jsonb` fields for complex data structures like `ability_scores` and `equipment` gives us flexibility while maintaining database efficiency. This becomes important when we start using LLMs to generate and modify character details - we can evolve our data structures without database migrations.

## Modern Rails: Real-time Updates with Turbo

Rails 8's Turbo Streams handles real-time updates without complex JavaScript frameworks. The system manages dynamic content through simple, predictable patterns, leveraging Rails 8's enhanced streaming capabilities for improved performance:

```ruby
class CharactersController < ApplicationController
  def create
    @character = Character.new(character_params)

    respond_to do |format|
      if @character.save
        # Turbo Streams enable real-time updates without custom JavaScript
        format.turbo_stream {
          render turbo_stream: [
            # Update multiple page elements independently
            turbo_stream.replace("character_sheet", partial: "characters/sheet", locals: { character: @character }),
            # Set up background section for streaming LLM content
            turbo_stream.update("background_section", partial: "characters/generating_background"),
            # Update character stats in real-time
            turbo_stream.replace("ability_scores", partial: "characters/ability_scores", locals: { character: @character }),
            # Refresh available actions based on character state
            turbo_stream.update("character_actions", partial: "characters/available_actions", locals: { character: @character })
          ]
        }
      else
        handle_validation_error(format)
      end
    end
  end
end
```

This controller demonstrates several key Rails patterns. When our character is created, we're updating multiple parts of the page independently and asynchronously. The character sheet, ability scores, and available actions all update in real-time without a full page reload. Most importantly, we're setting up the background section for streaming LLM-generated content.

Each `turbo_stream` action targets a specific DOM element, replacing or updating its content through a WebSocket connection. For our character generator, this means we can stream the LLM's response chunk by chunk, updating the background story as it's generated. This approach avoids the common pitfalls of client-side state management and provides a more responsive user experience.

We'll explore Turbo Streams and LLMs in depth in a future article, examining patterns for streaming token responses, handling partial updates, and managing multiple concurrent generations. The integration between Turbo Streams and LLMs creates some interesting possibilities for real-time AI applications that we'll want to examine carefully.

## The Path Forward

Our character generator demonstrates how Rails approaches modern web development through steady evolution. The framework's design encourages pragmatic solutions over unnecessary complexity.

This becomes particularly clear in our LLMService implementation:

```ruby
class Character < ApplicationRecord
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

# Background job for handling LLM interactions
class GenerateBackgroundJob < ApplicationJob
  def perform(character_id, messages:, system_prompt:)
    character = Character.find(character_id)
    # Make the actual LLM API call
    result = LLMService.chat(messages: messages, system_prompt: system_prompt)
    # Update the character with the generated background
    character.update(background: result)
    # Broadcast the update to all connected clients in real-time
    broadcast_replace_to character, target: "background_section", partial: "characters/background"
  end
end
```

In our next article, we'll examine the LLMService layer. We'll explore how Rails' conventions create a flexible provider system that handles AI integration effectively while maintaining clear, readable code. The framework's straightforward approach to architecture proves especially valuable when working with cutting-edge technologies.
