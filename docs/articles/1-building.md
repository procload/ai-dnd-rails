# LinkedIn Posts:

Boring technology might be the future of AI applications.

Starting a series building a D&D character generator that challenges our industry's obsession with complexity. Rails - with its predictable conventions, server-rendered HTML, and focus on simplicity - is an excellent match for the generative AI era.

Rails' established patterns align well with the needs of generative AI applications. The framework's steady evolution and focus on simplicity offer some interesting advantages for LLM integration.

Part 1 examines how Rails' approach to web development might be particularly relevant in the AI era. While our industry often equates innovation with complexity, there's value in examining proven patterns through this new lens.

Following articles will explore Rails' service architecture for LLMs, real-time updates, and how convention over configuration applies to AI workflows.

[link]

# Rails & AI: Building Our Character Generator

The tech industry has an interesting relationship with complexity. We often reach for intricate solutions when simpler ones might serve better. Modern web development exemplifies this tendency - layers of build tools, state management libraries, and framework abstractions that sometimes feel more like organizational theater than engineering solutions.

Ruby on Rails takes a different path. While other frameworks chase the latest architectural patterns, Rails has steadily evolved its server-rendered foundations. The framework's gradual incorporation of new features complements its core principles rather than replacing them.

The rise of AI-powered applications creates an opportunity to reconsider our approach to web development. Rails' convention over configuration philosophy makes it particularly well-suited for this new era. Clear, consistent rules create a solid foundation for building complex applications.

Rails' conventions created a vast, consistent pattern language across the internet. Every Stack Overflow answer, every GitHub repository, every Rails tutorial follows these patterns. This consistency, initially designed for human developers, has unexpectedly created an ideal training ground for AI systems. When modern LLMs parse Rails code, they're drawing on millions of examples that all follow the same conventions, speak the same language, and solve problems in similar ways.

To explore this, we'll build a D&D character generator. The project will demonstrate how Rails simplifies AI integration while maintaining clean architecture.

## Leveraging AI for Development

Modern AI tools have transformed our implementation of complex domain rules. Tools like GitHub Copilot and Cursor understand Rails conventions deeply, helping developers generate and refine rule-based logic efficiently. While the industry chases ever more complex toolchains, Rails' consistency offers a refreshing counterpoint.

We can lean on AI's ability to create domain-specific rules and logic such as D&D's ability modifiers and hit points. What normally would have been a back-and-forth between a developer and a rule manual, now becomes a simple prompt to an LLM.

```ruby
# Pure Ruby method demonstrating clean calculation pattern
# Shows how domain logic can be expressed clearly in Ruby
# Note the string key access pattern common in Rails params
def ability_modifier(ability)
  score = ability_scores[ability.to_s]
  (score - 10) / 2  # Ruby's integer division automatically floors
end

# Complex calculation method showing Ruby's enumerable features
# Demonstrates early return pattern and sum with block
def hit_points_at_level(level)
  # Early return for special case
  return CLASS_HIT_DICE[class_type] + constitution_modifier if level == 1

  # Base calculation
  base_hp = CLASS_HIT_DICE[class_type] + constitution_modifier

  # Use Range and Enumerable#sum for elegant iteration
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
# Required gems for modern Rails 8 features
gem 'activerecord-postgresql-adapter'  # Enables advanced PostgreSQL features
gem 'actiontext'                       # Rich text handling system

# Rails model generator showcasing modern database features
# Demonstrates PostgreSQL-specific column types for flexible data storage
# Benefits of jsonb over regular json:
# - Binary storage format for better performance
# - GiST and GIN indexing support
# - Constraint validation at database level
# - Efficient querying and indexing
rails generate model Character \
  name:string \
  class_type:string \
  level:integer \
  background:text \     # Will be replaced by ActionText
  alignment:string \
  ability_scores:jsonb \    # Flexible schema-less storage
  personality_traits:jsonb \ # Array storage without migrations
  equipment:jsonb \         # Nested JSON structure
  spells:jsonb             # Complex data in single column
```

This generator creates a standardized model structure that both humans and LLMs can predict and understand. Rails' naming conventions and file organization mean AI tools can reliably locate and modify related files - models, controllers, views, and tests all have consistent locations and naming patterns.

The model implementation demonstrates how Rails conventions naturally express domain rules:

```ruby
# Rails model showcasing modern features and patterns
class Character < ApplicationRecord
  # Class-level constants for validation and business logic
  CLASSES = %w[Barbarian Bard Cleric Druid Fighter Monk Paladin Ranger Rogue Sorcerer Warlock Wizard].freeze
  ALIGNMENTS = ['Lawful Good', 'Neutral Good', 'Chaotic Good', 'Lawful Neutral', 'True Neutral',
                'Chaotic Neutral', 'Lawful Evil', 'Neutral Evil', 'Chaotic Evil'].freeze
  ABILITIES = %w[strength dexterity constitution intelligence wisdom charisma].freeze
  CLASS_HIT_DICE = {'Barbarian' => 12, 'Fighter' => 10, 'Paladin' => 10, 'Ranger' => 10,
                    'Wizard' => 6, 'Sorcerer' => 6, 'Bard' => 8, 'Cleric' => 8,
                    'Druid' => 8, 'Monk' => 8, 'Rogue' => 8, 'Warlock' => 8}.freeze

  # ActiveRecord validations ensuring data integrity
  validates :name, presence: true
  validates :level, numericality: { in: 1..20 }
  validates :class_type, inclusion: { in: CLASSES }
  validates :alignment, inclusion: { in: ALIGNMENTS }

  # ActionText integration for rich content
  has_rich_text :background

  # Lifecycle callbacks for model initialization
  after_initialize :set_default_values, if: :new_record?
  before_save :ensure_arrays_initialized

  # Domain calculation using Ruby's math operations
  def proficiency_bonus
    ((level - 1) / 4) + 2
  end

  # Method handling nil values with Ruby's safe navigation
  def ability_modifier(ability)
    scores = ability_scores || {}
    score = scores[ability.to_s].to_i
    (score - 10) / 2
  end

  # Service object integration for LLM interaction
  def generate_background
    # Call mock service following Rails service pattern
    mock_data = MockLlmService.generate_background(self)

    # Clear rich text association before update
    self.background = nil

    # Use bang method for immediate validation
    update!(
      background: mock_data[:background],
      personality_traits: mock_data[:personality_traits]
    )
  end

  private

  # Callback method setting up new records
  def set_default_values
    # Initialize jsonb column with defaults
    self.ability_scores ||= ABILITIES.each_with_object({}) { |ability, scores| scores[ability] = 10 }

    # Generate initial content via service object
    mock_data = MockLlmService.generate_background(self)
    self.background = mock_data[:background]
    self.personality_traits = mock_data[:personality_traits]
  end

  # Ensure jsonb columns are properly initialized
  def ensure_arrays_initialized
    self.personality_traits ||= []
    self.equipment ||= []
    self.spells ||= []
  end
end

# Modern Rails controller with Turbo Streams integration
class CharactersController < ApplicationController
  # Standard Rails callback for DRY code
  before_action :set_character, only: [:show, :edit, :update, :destroy, :generate_background]

  # RESTful update action with Turbo Streams support
  def update
    respond_to do |format|
      if @character.update(character_params)
        format.turbo_stream {
          # Multiple Turbo Stream updates in single response
          render turbo_stream: [
            turbo_stream.replace("character_sheet",
                               partial: "characters/sheet",
                               locals: { character: @character }),
            turbo_stream.replace("ability_scores",
                               partial: "characters/ability_scores",
                               locals: { character: @character })
          ]
        }
        format.html { redirect_to @character, notice: "Character was successfully updated." }
      else
        format.html { render :edit, status: :unprocessable_entity }
        # Error handling with Turbo Streams
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace(
            "character_form",
            partial: "form",
            locals: { character: @character }
          )
        }
      end
    end
  end

  # Custom action demonstrating Turbo Streams flexibility
  def generate_background
    Rails.logger.debug "Starting generate_background for character #{@character.id}"
    @character.generate_background

    respond_to do |format|
      # Single Turbo Stream update
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "background_section",
          partial: "characters/background",
          locals: { character: @character }
        )
      end
      format.html { redirect_to @character }
    end
  end

  private

  # Strong parameters pattern with nested attributes
  def character_params
    params.require(:character).permit(
      :name, :class_type, :level, :alignment, :background,
      ability_scores: Character::ABILITIES
    )
  end
end
```

When you ask an LLM to "add a new validation for character alignment" or "implement the proficiency bonus calculation," it understands exactly where that code should go and how it should be structured. The framework's conventions create a sort of shared language between human developers, existing codebases, and AI tools.

Rails conventions make this code particularly suitable for LLM-based workflows. The constants at the top of the file define clear boundaries for valid data. Validation rules express business logic in a declarative style that AI tools can easily understand and modify. Method names follow consistent patterns that make their purpose clear without excessive documentation.

The use of `jsonb` fields for complex data structures like `ability_scores` and `equipment` gives us flexibility while maintaining database efficiency. This becomes important when we start using LLMs to generate and modify character details - we can evolve our data structures without database migrations.

### Pragmatic Development with Mock Services

Rails' emphasis on pragmatic development shines in our approach to LLM integration. Rather than immediately tackling the complexities of API integration, we begin with a mock service that demonstrates the intended functionality:

```ruby
# Mock responses provide a foundation for iterative development
{
  "backgrounds": [
    {
      "class_type": "ANY",
      "alignment": "ANY",
      "background": "Raised in a remote village, they discovered their calling after defending their home from bandits...",
      "personality_traits": [
        "Believes in standing up for the underdog",
        "Values community above all",
        "Shares wisdom from their village",
        "Faces challenges head-on"
      ]
    }
  ]
}
```

This approach offers several advantages:

1. Rapid prototyping without external dependencies
2. Clear contract for the eventual LLM integration
3. Reliable test data during development
4. Smooth transition path to production services

## Modern Rails: Real-time Updates with Turbo

The predictability of Rails extends far beyond models. Watch any experienced Rails developer work, and you'll notice they rarely need to look up controller patterns or routing conventions. They know exactly where code should go, how it should be structured, and what to name things.

What's fascinating is that modern AI tools have developed the same intuition. Feed an LLM a brief description of what you want your controller to do, and it'll generate a complete, properly structured action - routes, strong parameters, and all. The framework's conventions around naming, file structure, and HTTP verbs have essentially created a shared language that both humans and machines speak fluently.

This becomes particularly clear in our character generator's controller:

```ruby
# Synchronous service integration
# Shows basic Rails service object pattern
def generate_background
  mock_data = MockLlmService.generate_background(self)
  update!(
    background: mock_data[:background],
    personality_traits: mock_data[:personality_traits]
  )
end

# Asynchronous job enqueuing
# Demonstrates Rails' ActiveJob integration
def generate_background
  GenerateBackgroundJob.perform_later(
    id,
    messages: character_prompt,      # Job arguments
    system_prompt: background_guidelines  # Configuration data
  )
end

# ActiveJob class showing Rails' background processing
# Integrates with Action Cable for real-time updates
class GenerateBackgroundJob < ApplicationJob
  def perform(character_id, messages:, system_prompt:)
    character = Character.find(character_id)
    # External service integration
    result = LLMService.chat(messages: messages, system_prompt: system_prompt)
    # ActiveRecord update
    character.update(background: result)
    # Action Cable broadcast
    broadcast_replace_to character, target: "background_section", partial: "characters/background"
  end
end
```

This controller demonstrates several key Rails patterns. When our character is created, we're updating multiple parts of the page independently and asynchronously. The character sheet, ability scores, and available actions all update in real-time without a full page reload. Most importantly, we're setting up the background section for streaming LLM-generated content.

Each `turbo_stream` action targets a specific DOM element, replacing or updating its content through a WebSocket connection. For our character generator, this means we can stream the LLM's response chunk by chunk, updating the background story as it's generated. This approach avoids the common pitfalls of client-side state management and provides a more responsive user experience.

We'll explore Turbo Streams and LLMs in depth in a future article, examining patterns for streaming token responses, handling partial updates, and managing multiple concurrent generations. The integration between Turbo Streams and LLMs creates some interesting possibilities for real-time AI applications that we'll want to examine carefully.

### Evolution from Synchronous to Asynchronous Processing

Our character generator demonstrates Rails' strength in managing evolving complexity. The progression from synchronous processing to background jobs happens naturally:

1. Start with direct service calls for rapid development and testing
2. Extract service logic when ready for real LLM integration
3. Move to background processing when needed for better user experience

This evolution requires minimal architectural changes thanks to Rails' integrated tools - ActiveJob for background processing and Action Cable for real-time updates work seamlessly with our existing patterns.

In our next article about the LLMService layer, we'll explore how this evolution continues as we add support for multiple LLM providers and more sophisticated streaming patterns.

While we prepare to deploy this application for public use, you can explore the codebase today. The complete source code is available on GitHub at [github.com/ryanmerrill/dnd-rails](https://github.com/ryanmerrill/dnd-rails). The repository includes a comprehensive README with setup instructions for running the application locally. Rails' strong conventions and the project's minimal dependencies make it straightforward to get up and running - just clone the repository, follow the README's setup steps, and you'll have your own D&D character generator with AI integration running locally.
