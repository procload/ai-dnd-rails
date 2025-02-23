class ModifyImageMetadataColumn < ActiveRecord::Migration[8.0]
  def up
    # First, ensure any existing NULL values are converted to empty JSON objects
    execute <<-SQL
      UPDATE characters 
      SET image_metadata = '{}' 
      WHERE image_metadata IS NULL;
    SQL

    # Then convert the column to JSONB with proper USING clause
    change_column :characters, :image_metadata, :jsonb, 
                 default: {}, 
                 null: false,
                 using: "CASE 
                          WHEN image_metadata IS NULL THEN '{}'::jsonb
                          ELSE image_metadata::jsonb 
                        END"
  end

  def down
    change_column :characters, :image_metadata, :text
  end
end 