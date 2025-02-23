class CharacterPortrait < ApplicationRecord
  belongs_to :character
  has_one_attached :image do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 100]
    attachable.variant :medium, resize_to_limit: [300, 300]
    attachable.variant :large, resize_to_limit: [800, 800]
  end

  validates :image, presence: true
  validates :character, presence: true
  
  # Track if this is the currently selected portrait
  scope :selected, -> { where(selected: true) }
  scope :most_recent_first, -> { order(created_at: :desc) }

  after_save :ensure_only_one_selected, if: :selected?

  private

  def ensure_only_one_selected
    character.character_portraits.where.not(id: id).update_all(selected: false)
  end
end 