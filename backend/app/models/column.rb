class Column < ApplicationRecord
  belongs_to :board
  has_many :card_states, dependent: :nullify

  validates :title, :position, presence: true

  scope :ordered, -> { order(:position) }
end
