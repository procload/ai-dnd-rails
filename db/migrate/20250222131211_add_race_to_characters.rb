class AddRaceToCharacters < ActiveRecord::Migration[8.0]
  def change
    add_column :characters, :race, :string
  end
end 