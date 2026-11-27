# Manual placement of a session card on one board (Trello-style move).
# Rows are created lazily by the scanner; sessions without a row for the
# active board are treated as "new" and land in the first column.
class CardState < ApplicationRecord
  belongs_to :board
  belongs_to :column, optional: true
  belongs_to :session_record, primary_key: :pi_id, foreign_key: :pi_id, optional: true

  validates :pi_id, presence: true
  validates :pi_id, uniqueness: { scope: :board_id }
  validates :kind, inclusion: { in: %w[manual automated] }
  validates :title, presence: true, if: :manual?

  def manual?
    kind == "manual"
  end

  scope :manual, -> { where(kind: "manual") }
  scope :in_column, ->(column) { where(column_id: column.id) }
end
