class CreateCharacterPortraits < ActiveRecord::Migration[8.0]
  def change
    create_table :character_portraits do |t|
      t.references :character, null: false, foreign_key: true
      t.boolean :selected, default: false, null: false
      t.timestamps
    end

    # Add an index to help with finding selected portraits
    add_index :character_portraits, [:character_id, :selected], 
              where: "selected = true", 
              unique: true, 
              name: 'index_character_portraits_on_character_id_and_selected'
  end
end 