# Full or incremental scan of the pi sessions tree → upsert session_records,
# auto-create boards per project directory and place new sessions in the
# first column (Grounding).
class SessionScanner
  attr_reader :root

  def initialize(root = ENV.fetch("SESSIONS_ROOT", "/sessions"))
    @root = Pathname.new(root)
  end

  # Idempotent: safe to run on every boot.
  def full_scan
    return unless @root.directory?

    project_dirs = Dir.children(@root)
                      .select { |d| (@root / d).directory? }
                      .select { |d| Dir.glob(@root / d / "*.jsonl").any? }

    project_dirs.each do |dir|
      board = upsert_board(dir)
      Dir.glob(@root / dir / "*.jsonl") do |f|
        upsert_file(f)
      rescue StandardError => e
        Rails.logger.warn("[SessionScanner] failed on #{f}: #{e.class}: #{e.message}")
      end
    end

    # Boards whose project directory disappeared (or never had sessions)
    Board.where.not(project_dir: project_dirs).destroy_all

    # Session files that were deleted on disk
    existing = Dir.glob(@root / "*" / "*.jsonl").to_set
    SessionRecord.where.not(file_path: existing).destroy_all
  end

  # Incremental: called by the watcher for a single file.
  def upsert_file(path)
    result = SessionFileParser.new(path).call
    return nil unless result

    project_dir = File.basename(File.dirname(path))
    upsert_board(project_dir)
    session = SessionRecord.find_or_initialize_by(file_path: path.to_s)
    if session.new_record?
      # A file may have MOVED to another project dir: same pi_id, new path.
      # Reuse the existing record instead of hitting the uniqueness check.
      session = SessionRecord.find_by(pi_id: result.pi_id) || session
    end
    session.update!(pi_id: result.pi_id, file_path: path.to_s, project_dir: project_dir,
                    name: result.name, preview: result.preview,
                    model: result.model, tokens: result.tokens, cost: result.cost,
                    created_at_session: result.created_at_session,
                    updated_at_session: result.updated_at_session)

    # New sessions land in the first column unless the user moved them already.
    board = Board.find_by!(project_dir: project_dir)
    card = CardState.find_or_create_by!(board: board, pi_id: result.pi_id) do |cs|
      cs.column = board.first_column
      cs.position = (board.first_column&.card_states&.maximum(:position) || -1) + 1
    end

    { session: session, card_state: card }
  end

  def remove_file(path)
    session = SessionRecord.find_by(file_path: path.to_s)
    return nil unless session

    CardState.where(pi_id: session.pi_id).destroy_all
    session.destroy
    { removed: session.pi_id }
  end

  private

  def upsert_board(project_dir)
    Board.find_or_create_by!(project_dir: project_dir) do |b|
      b.name = Board.new(project_dir: project_dir).human_leaf
    end.tap(&:ensure_default_columns!)
  end
end
