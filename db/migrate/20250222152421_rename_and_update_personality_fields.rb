class RenameAndUpdatePersonalityFields < ActiveRecord::Migration[7.1]
  def up
    # Create character_values if personality_details doesn't exist
    unless column_exists?(:characters, :personality_details)
      add_column :characters, :character_values, :jsonb, default: { 'ideals' => [], 'bonds' => [], 'flaws' => [] }
    else
      rename_column :characters, :personality_details, :character_values
    end

    # Then, create a temporary column for the new traits structure
    add_column :characters, :character_traits, :jsonb, default: []

    # Migrate existing personality_traits data to the new structure
    execute <<-SQL
      UPDATE characters
      SET character_traits = (
        SELECT COALESCE(
          jsonb_agg(
            jsonb_build_object(
              'trait', value,
              'category', 'general',
              'description', NULL
            )
          ),
          '[]'::jsonb
        )
        FROM jsonb_array_elements_text(personality_traits)
      )
      WHERE personality_traits IS NOT NULL;
    SQL

    # Remove the old personality_traits column
    remove_column :characters, :personality_traits if column_exists?(:characters, :personality_traits)

    # Add any necessary indexes
    add_index :characters, :character_traits, using: :gin
    add_index :characters, :character_values, using: :gin
  end

  def down
    # Add back personality_traits
    add_column :characters, :personality_traits, :jsonb, default: []

    # Migrate data back to the old structure
    execute <<-SQL
      UPDATE characters
      SET personality_traits = (
        SELECT COALESCE(
          jsonb_agg(value->>'trait'),
          '[]'::jsonb
        )
        FROM jsonb_array_elements(character_traits)
      )
      WHERE character_traits IS NOT NULL;
    SQL

    # Remove the new columns and indexes
    remove_index :characters, :character_traits
    remove_index :characters, :character_values
    remove_column :characters, :character_traits
    rename_column :characters, :character_values, :personality_details
  end
end
