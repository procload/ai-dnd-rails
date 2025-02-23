class AddBackgroundAndConstraintsToCharacters < ActiveRecord::Migration[8.0]
  def change
    # Add background field with ActionText support
    add_column :characters, :background, :text

    # Set default values for existing records
    execute(<<-SQL)
      UPDATE characters
      SET equipment = '{"weapons": [], "armor": [], "adventuring_gear": []}'::jsonb
      WHERE equipment IS NULL OR NOT (
        equipment ? 'weapons' AND 
        equipment ? 'armor' AND 
        equipment ? 'adventuring_gear'
      );

      UPDATE characters
      SET spells = '{"cantrips": [], "level_1_spells": []}'::jsonb
      WHERE spells IS NULL OR NOT (
        spells ? 'cantrips' AND 
        spells ? 'level_1_spells'
      );

      UPDATE characters
      SET personality_traits = '[]'::jsonb
      WHERE personality_traits IS NULL;
    SQL

    # Now add the constraints
    execute(<<-SQL)
      ALTER TABLE characters
      ADD CONSTRAINT personality_traits_length_check
      CHECK (
        jsonb_array_length(personality_traits) BETWEEN 0 AND 4
      );

      ALTER TABLE characters
      ADD CONSTRAINT equipment_arrays_length_check
      CHECK (
        jsonb_array_length(equipment->'weapons') BETWEEN 0 AND 4 AND
        jsonb_array_length(equipment->'armor') BETWEEN 0 AND 2 AND
        jsonb_array_length(equipment->'adventuring_gear') BETWEEN 0 AND 8
      );

      ALTER TABLE characters
      ADD CONSTRAINT spells_arrays_length_check
      CHECK (
        jsonb_array_length(spells->'cantrips') BETWEEN 0 AND 4 AND
        jsonb_array_length(spells->'level_1_spells') BETWEEN 0 AND 4
      );

      -- Add check constraints for required object keys
      ALTER TABLE characters
      ADD CONSTRAINT equipment_required_keys_check
      CHECK (
        equipment ? 'weapons' AND
        equipment ? 'armor' AND
        equipment ? 'adventuring_gear'
      );

      ALTER TABLE characters
      ADD CONSTRAINT spells_required_keys_check
      CHECK (
        spells ? 'cantrips' AND
        spells ? 'level_1_spells'
      );
    SQL

    # Add NOT NULL constraints after setting defaults
    change_column_null :characters, :equipment, false
    change_column_null :characters, :spells, false
    change_column_null :characters, :personality_traits, false

    # Set default values for new records
    change_column_default :characters, :equipment, from: nil, to: { weapons: [], armor: [], adventuring_gear: [] }.to_json
    change_column_default :characters, :spells, from: nil, to: { cantrips: [], level_1_spells: [] }.to_json
    change_column_default :characters, :personality_traits, from: nil, to: [].to_json
  end

  def down
    remove_column :characters, :background

    execute(<<-SQL)
      ALTER TABLE characters DROP CONSTRAINT IF EXISTS personality_traits_length_check;
      ALTER TABLE characters DROP CONSTRAINT IF EXISTS equipment_arrays_length_check;
      ALTER TABLE characters DROP CONSTRAINT IF EXISTS spells_arrays_length_check;
      ALTER TABLE characters DROP CONSTRAINT IF EXISTS equipment_required_keys_check;
      ALTER TABLE characters DROP CONSTRAINT IF EXISTS spells_required_keys_check;
    SQL

    change_column_null :characters, :equipment, true
    change_column_null :characters, :spells, true
    change_column_null :characters, :personality_traits, true

    change_column_default :characters, :equipment, nil
    change_column_default :characters, :spells, nil
    change_column_default :characters, :personality_traits, nil
  end
end 