class InitializeCharacterArrays < ActiveRecord::Migration[8.0]
  def up
    Character.find_each do |character|
      character.personality_traits ||= []
      character.equipment ||= []
      character.spells ||= []
      character.save!
    end
  end

  def down
    # No need for rollback as we're just initializing empty arrays
  end
end 