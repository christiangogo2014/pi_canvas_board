# A card annotation tied to a pi session (by pi_id, board-agnostic):
# a description (one per session), comments, or file attachments.
# Ordered by created_at this forms the card's timeline.
class CardNote < ApplicationRecord
  KINDS = %w[description comment attachment].freeze

  belongs_to :session_record, primary_key: :pi_id, foreign_key: :pi_id

  validates :pi_id, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :body, presence: true, unless: :attachment?
  validates :attachment_filename, presence: true, if: :attachment?
  validate :single_description_per_session

  scope :timeline, -> { order(:created_at, :id) }

  def attachment?
    kind == "attachment"
  end

  private

  def single_description_per_session
    return unless kind == "description"
    existing = CardNote.where(pi_id: pi_id, kind: "description").where.not(id: id)
    errors.add(:kind, "already has a description for this session") if existing.exists?
  end
end
