# A pi coding-agent session parsed from ~/.pi/agent/sessions/**.jsonl.
# Table name is session_records because "Session" reads badly in Rails.
class SessionRecord < ApplicationRecord
  has_many :card_states, primary_key: :pi_id, foreign_key: :pi_id, dependent: :destroy
  has_many :card_notes, primary_key: :pi_id, foreign_key: :pi_id, dependent: :destroy

  validates :pi_id, :file_path, :project_dir, presence: true
  validates :pi_id, uniqueness: true
  validates :file_path, uniqueness: true

  scope :for_project, ->(project_dir) { where(project_dir: project_dir) }
  scope :named, -> { where.not(name: nil) }

  # Display title: session_info name, else first user message preview,
  # else the pi session id prefix.
  def display_name
    name || preview || pi_id[0, 8]
  end

  def to_param
    pi_id
  end
end
