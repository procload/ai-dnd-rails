class CharactersController < ApplicationController
  before_action :set_character, except: [:index, :new, :create]

  def index
    @characters = Character.all.order(created_at: :desc)
  end

  def show
  end

  def new
    @character = Character.new
  end

  def edit
  end

  def create
    # Transform ability scores from form parameters to the expected format
    transformed_params = character_params
    ability_scores = {}
    Character::ABILITIES.each do |ability|
      score = params.dig(:character, "ability_scores.#{ability}")
      ability_scores[ability] = score if score.present?
    end
    transformed_params[:ability_scores] = ability_scores if ability_scores.present?

    @character = Character.new(transformed_params)

    if @character.save
      redirect_to @character, notice: 'Character was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    # Transform ability scores from form parameters to the expected format
    transformed_params = character_params
    ability_scores = {}
    Character::ABILITIES.each do |ability|
      score = params.dig(:character, "ability_scores.#{ability}")
      ability_scores[ability] = score if score.present?
    end
    transformed_params[:ability_scores] = ability_scores if ability_scores.present?

    if @character.update(transformed_params)
      redirect_to @character, notice: 'Character was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @character.destroy
    redirect_to characters_url, notice: 'Character was successfully deleted.'
  end

  # Generation endpoints
  def generate_background
    Rails.logger.debug "Starting generate_background for character #{@character.id}"
    @character.generate_background
    Rails.logger.debug "Background generated, personality_traits: #{@character.personality_traits.inspect}"
    Rails.logger.debug "Background text: #{@character.background.to_plain_text}"
    
    respond_to do |format|
      format.turbo_stream do
        Rails.logger.debug "Rendering Turbo Stream response"
        render turbo_stream: turbo_stream.replace(
          "background_section",
          partial: "characters/background",
          locals: { character: @character }
        )
      end
      format.html { redirect_to @character }
    end
  rescue StandardError => e
    Rails.logger.error "Failed to generate background: #{e.message}"
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("flash", partial: "shared/flash", locals: { message: e.message, type: :error }),
          turbo_stream.replace("background_section", partial: "characters/background", locals: { character: @character })
        ]
      end
      format.html { redirect_to @character, alert: e.message }
    end
  end

  def generate_portrait
    @character = Character.find(params[:id])
    Rails.logger.debug "[CharactersController] Starting portrait generation for character #{@character.id}"
    
    portrait = @character.generate_portrait
    Rails.logger.debug "[CharactersController] Portrait generated successfully: #{portrait.inspect}"
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "character_portrait",
          partial: "characters/current_portrait",
          locals: { character: @character }
        )
      end
    end
  rescue StandardError => e
    Rails.logger.error "[CharactersController] Portrait generation failed: #{e.message}"
    Rails.logger.error "[CharactersController] Error class: #{e.class}"
    Rails.logger.error "[CharactersController] Backtrace:\n#{e.backtrace.join("\n")}"
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "character_portrait",
          partial: "characters/current_portrait",
          locals: { character: @character, error: e.message }
        )
      end
    end
  end

  def generate_personality_details
    Rails.logger.debug "Starting generate_personality_details for character #{@character.id}"
    @character.generate_personality_details
    Rails.logger.debug "Personality details generated: #{@character.personality_details.inspect}"
    
    respond_to do |format|
      format.turbo_stream do
        Rails.logger.debug "Rendering Turbo Stream response"
        render turbo_stream: turbo_stream.replace(
          "personality_details_section",
          partial: "characters/personality_details",
          locals: { character: @character }
        )
      end
      format.html { redirect_to @character }
    end
  rescue StandardError => e
    Rails.logger.error "Failed to generate personality details: #{e.message}"
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("flash", partial: "shared/flash", locals: { message: e.message, type: :error }),
          turbo_stream.replace("personality_details_section", partial: "characters/personality_details", locals: { character: @character })
        ]
      end
      format.html { redirect_to @character, alert: e.message }
    end
  end

  def generate_traits
    Rails.logger.debug "Starting generate_traits for character #{@character.id}"
    @character.generate_traits
    Rails.logger.debug "Traits generated: #{@character.personality_traits.inspect}"
    
    respond_to do |format|
      format.turbo_stream do
        Rails.logger.debug "Rendering Turbo Stream response"
        render turbo_stream: turbo_stream.replace(
          "personality_traits_section",
          partial: "characters/personality_traits",
          locals: { character: @character }
        )
      end
      format.html { redirect_to @character }
    end
  rescue StandardError => e
    Rails.logger.error "Failed to generate traits: #{e.message}"
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("flash", partial: "shared/flash", locals: { message: e.message, type: :error }),
          turbo_stream.replace("personality_traits_section", partial: "characters/personality_traits", locals: { character: @character })
        ]
      end
      format.html { redirect_to @character, alert: e.message }
    end
  end

  def generate_character_values
    Rails.logger.debug "Starting generate_character_values for character #{@character.id}"
    @character.generate_character_values
    Rails.logger.debug "Character values generated: #{@character.character_values.inspect}"
    
    respond_to do |format|
      format.turbo_stream do
        Rails.logger.debug "Rendering Turbo Stream response"
        render turbo_stream: turbo_stream.replace(
          "character_values_section",
          partial: "characters/character_values",
          locals: { character: @character }
        )
      end
      format.html { redirect_to @character }
    end
  rescue StandardError => e
    Rails.logger.error "Failed to generate character values: #{e.message}"
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("flash", partial: "shared/flash", locals: { message: e.message, type: :error }),
          turbo_stream.replace("character_values_section", partial: "characters/character_values", locals: { character: @character })
        ]
      end
      format.html { redirect_to @character, alert: e.message }
    end
  end

  def generate_equipment_suggestions
    Rails.logger.debug "Starting equipment generation for character #{@character.id}"
    @character.generate_equipment_suggestions
    Rails.logger.debug "Equipment generated: #{@character.equipment.inspect}"
    
    respond_to do |format|
      format.turbo_stream do
        Rails.logger.debug "Rendering Turbo Stream response"
        render turbo_stream: turbo_stream.replace(
          "equipment_section",
          partial: "characters/equipment",
          locals: { character: @character }
        )
      end
      format.html { redirect_to @character }
    end
  rescue StandardError => e
    Rails.logger.error "Failed to generate equipment: #{e.message}"
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("flash", partial: "shared/flash", locals: { message: e.message, type: :error }),
          turbo_stream.replace("equipment_section", partial: "characters/equipment", locals: { character: @character })
        ]
      end
      format.html { redirect_to @character, alert: e.message }
    end
  end

  def generate_spell_suggestions
    Rails.logger.debug "Starting generate_spell_suggestions for character #{@character.id}"
    @character.generate_spell_suggestions
    Rails.logger.debug "Spell suggestions generated: #{@character.spells.inspect}"
    
    respond_to do |format|
      format.turbo_stream do
        Rails.logger.debug "Rendering Turbo Stream response"
        render turbo_stream: turbo_stream.replace(
          "spells_section",
          partial: "characters/spells",
          locals: { character: @character }
        )
      end
      format.html { redirect_to @character }
    end
  rescue StandardError => e
    Rails.logger.error "Failed to generate spell suggestions: #{e.message}"
    respond_to do |format|
      format.turbo_stream do
        flash.now[:error] = e.message
        render turbo_stream: [
          turbo_stream.update("flash", partial: "shared/flash"),
          turbo_stream.replace("spells_section", 
            partial: "characters/spells", 
            locals: { character: @character }
          )
        ]
      end
      format.html {
        flash[:error] = e.message
        redirect_to @character
      }
    end
  end

  private

  def set_character
    @character = Character.find(params[:id])
  end

  def character_params
    params.require(:character).permit(
      :name,
      :class_type,
      :level,
      :alignment,
      :background,
      :race,
      :ability_scores
    )
  end
end 