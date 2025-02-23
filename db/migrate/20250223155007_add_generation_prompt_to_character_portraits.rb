class AddGenerationPromptToCharacterPortraits < ActiveRecord::Migration[8.0]
  def change
    add_column :character_portraits, :generation_prompt, :text
  end
end
