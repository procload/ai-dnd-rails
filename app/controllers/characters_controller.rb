class CharactersController < ApplicationController
  before_action :set_character, only: [:show, :edit, :update, :destroy, :generate_background]

  def index
    @characters = Character.all
  end

  def show
  end

  def new
    @character = Character.new
  end

  def edit
  end

  def create
    @character = Character.new(character_params)

    respond_to do |format|
      if @character.save
        format.turbo_stream { 
          redirect_to character_path(@character), notice: "Character was successfully created."
        }
        format.html { redirect_to character_path(@character), notice: "Character was successfully created." }
      else
        format.html { render :new, status: :unprocessable_entity }
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

  def update
    respond_to do |format|
      if @character.update(character_params)
        format.html { redirect_to @character, notice: "Character was successfully updated." }
        format.turbo_stream { redirect_to @character, notice: "Character was successfully updated." }
      else
        format.html { render :edit, status: :unprocessable_entity }
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

  def destroy
    @character.destroy

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@character) }
      format.html { redirect_to characters_url, notice: "Character was successfully deleted." }
    end
  end

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
      ability_scores: Character::ABILITIES
    )
  end
end
