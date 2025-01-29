class CreateCharacters < ActiveRecord::Migration[8.0]
  def change
    create_table :characters do |t|
      t.string :name
      t.string :class_type
      t.integer :level
      t.string :alignment
      t.jsonb :ability_scores
      t.jsonb :personality_traits
      t.jsonb :equipment
      t.jsonb :spells

      t.timestamps
    end
  end
end
