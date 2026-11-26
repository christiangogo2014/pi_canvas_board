class Board < ApplicationRecord
  SORT_FIELDS = %w[created_at_session updated_at_session].freeze
  DEFAULT_COLUMNS = ["Grounding", "ToDo", "In Progress", "QA", "Deployed", "Done"].freeze
  ACRONYMS = %w[be mx fe api ui cd ci db sdk].freeze

  has_many :columns, dependent: :destroy
  has_many :card_states, dependent: :destroy

  before_create :assign_position, unless: :position?

  validates :name, :project_dir, presence: true
  validates :project_dir, uniqueness: true
  validates :sort_field, inclusion: { in: SORT_FIELDS }
  validates :sort_dir, inclusion: { in: %w[asc desc] }

  scope :ordered, -> { order(:position, :name) }

  # "--Users-chr-conversa--" -> "/Users/chr/conversa"
  def project_path
    "/" + project_dir.delete_prefix("--").delete_suffix("--").tr("-", "/")
  end

  # Human board title: the project folder name, humanized.
  # "--Users-chr-conversa--" -> "Conversa"; "...conversa_be" -> "Conversa BE"
  def human_leaf
    leaf = project_path.split("/").reject(&:blank?).last
    return "Home" if leaf == "chr" && project_path == "/Users/chr"

    leaf.split(/[\-_]/).map do |w|
      ACRONYMS.include?(w.downcase) ? w.upcase : w.capitalize
    end.join(" ")
  end

  # Muted subtitle for the UI: the parent context, leaf excluded.
  # "--Users-chr-projects-chatbot_gems--" -> "~/projects"
  def short_path
    path = project_path
    return "~" if path == "/Users/chr"

    parent = path.split("/")[0..-2].join("/")
    parent.empty? ? "/" : parent.sub(%r{\A/Users/chr\z}, "~").sub(%r{\A/Users/chr/}, "~/")
  end

  # Scrum-friendly default column set for a newly detected project directory.
  def ensure_default_columns!
    return if columns.exists?
    DEFAULT_COLUMNS.each_with_index { |title, i| columns.create!(title: title, position: i) }
  end

  def first_column
    columns.order(:position).first
  end

  # Sessions for this board that have no manual placement yet
  def unplaced_sessions
    SessionRecord.where(project_dir: project_dir)
                 .where.not(pi_id: card_states.select(:pi_id))
  end

  def ordered_sessions_for(column)
    SessionRecord.joins(:card_states)
                 .where(card_states: { board_id: id, column_id: column.id })
                 .order(Arel.sql("#{sort_field} #{sort_dir}"), "card_states.position ASC")
  end

  private

  # New boards go last in the manual drag & drop order.
  def assign_position
    self.position = (Board.maximum(:position) || -1) + 1
  end
end
