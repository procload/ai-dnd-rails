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
          render turbo_stream: [
            turbo_stream.replace("character_sheet", partial: "characters/sheet", locals: { character: @character }),
            turbo_stream.update("background_section", partial: "characters/generating_background"),
            turbo_stream.replace("ability_scores", partial: "characters/ability_scores", locals: { character: @character }),
            turbo_stream.update("character_actions", partial: "characters/available_actions", locals: { character: @character })
          ]
        }
        format.html { redirect_to @character, notice: "Character was successfully created." }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("character_form", partial: "form", locals: { character: @character }) }
      end
    end
  end

  def update
    respond_to do |format|
      if @character.update(character_params)
        format.turbo_stream {
          render turbo_stream: [
            turbo_stream.replace("character_sheet", partial: "characters/sheet", locals: { character: @character }),
            turbo_stream.replace("ability_scores", partial: "characters/ability_scores", locals: { character: @character })
          ]
        }
        format.html { redirect_to @character, notice: "Character was successfully updated." }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("character_form", partial: "form", locals: { character: @character }) }
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
    @character.generate_background
    
    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: turbo_stream.update("background_section", 
          partial: "characters/generating_background")
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
      ability_scores: ABILITIES,
      personality_traits: [],
      equipment: [],
      spells: []
    )
  end
end
