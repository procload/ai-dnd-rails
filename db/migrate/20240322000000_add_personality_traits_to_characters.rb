class AddPersonalityTraitsToCharacters < ActiveRecord::Migration[8.0]
  def change
    add_column :characters, :personality_traits, :string, array: true, default: []
  end
end 