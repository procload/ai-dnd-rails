class AddImageStatusToCharacters < ActiveRecord::Migration[8.0]
  def change
    add_column :characters, :image_status, :integer, null: false, default: 0
    add_index :characters, :image_status
  end
end
