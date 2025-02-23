class AddImageFieldsToCharacters < ActiveRecord::Migration[8.0]
  def change
    add_column :characters, :image_metadata, :text
  end
end 