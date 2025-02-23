class AddPersonalityDetailsToCharacters < ActiveRecord::Migration[8.0]
  def change
    add_column :characters, :personality_details, :jsonb, default: { bonds: [], flaws: [], ideals: [] }
  end
end 