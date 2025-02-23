class CharacterPortraitsController < ApplicationController
  before_action :set_character
  before_action :set_portrait, only: [:select]

  def index
    @portraits = @character.character_portraits.most_recent_first
  end

  def select
    @character.select_portrait(@portrait)

    respond_to do |format|
      format.html { redirect_to character_portraits_path(@character), notice: "Portrait selected successfully." }
      format.turbo_stream {
        flash.now[:notice] = "Portrait selected successfully."
        render turbo_stream: [
          turbo_stream.replace("character_portrait", 
            partial: "characters/current_portrait", 
            locals: { character: @character }
          ),
          turbo_stream.replace("portrait_gallery",
            partial: "characters/portrait_gallery",
            locals: { character: @character }
          ),
          turbo_stream.replace("flash", 
            partial: "shared/flash"
          )
        ]
      }
    end
  end

  private

  def set_character
    @character = Character.find(params[:character_id])
  end

  def set_portrait
    @portrait = @character.character_portraits.find(params[:id])
  end
end 