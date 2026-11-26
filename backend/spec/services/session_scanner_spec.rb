require "rails_helper"

RSpec.describe SessionScanner do
  let(:root) { Dir.mktmpdir("sessions_root") }
  let(:scanner) { described_class.new(root) }
  let(:project_dir) { "--Users-chr-conversa--" }

  def write_session_file(dir: project_dir, id: "01a159f4-test", name: nil, ts: "2026-10-20T15:36:25.814Z")
    entries = [{ "type" => "session", "version" => 3, "id" => id,
                 "timestamp" => ts, "cwd" => "/Users/chr/conversa" }]
    entries << { "type" => "session_info", "id" => "s", "parentId" => nil,
                 "timestamp" => ts, "name" => name } if name
    Dir.mkdir(File.join(root, dir)) unless File.directory?(File.join(root, dir))
    path = File.join(root, dir, "#{Time.iso8601(ts).strftime("%Y-%m-%dT%H-%M-%S-%3NZ")}_#{id}.jsonl")
    File.write(path, entries.map(&:to_json).join("\n") << "\n")
    path
  end

  after { FileUtils.remove_entry(root) }

  describe "#full_scan" do
    it "creates one board per project directory with scrum columns" do
      write_session_file
      scanner.full_scan

      board = Board.find_by!(project_dir: project_dir)
      expect(board.name).to eq("Conversa")
      expect(board.columns.order(:position).map(&:title))
        .to eq(%w[Grounding ToDo In\ Progress QA Deployed Done])
    end

    it "places new sessions in the first column (Grounding)" do
      write_session_file(id: "aaa")
      scanner.full_scan

      card = CardState.find_by!(pi_id: "aaa")
      expect(card.column.title).to eq("Grounding")
    end

    it "is idempotent across runs" do
      path = write_session_file(id: "bbb")
      2.times { scanner.full_scan }
      expect(Board.count).to eq(1)
      expect(SessionRecord.count).to eq(1)
      expect(CardState.count).to eq(1)
    end

    it "removes sessions whose files disappeared, and boards whose dirs disappeared" do
      path = write_session_file(id: "ccc")
      scanner.full_scan
      expect(Board.count).to eq(1)

      File.delete(path)
      scanner.full_scan
      expect(SessionRecord.count).to eq(0)
      expect(CardState.count).to eq(0)
      expect(Board.count).to eq(0) # dir empty → board dropped

      Dir.rmdir(File.join(root, project_dir))
      scanner.full_scan
      expect(Board.count).to eq(0)
    end
  end

  describe "#upsert_file" do
    it "creates board, session and card incrementally" do
      path = write_session_file(id: "ddd", name: "Watcher test")
      result = scanner.upsert_file(path)

      expect(result[:session].name).to eq("Watcher test")
      expect(result[:card_state].column.title).to eq("Grounding")
      expect(Board.count).to eq(1)
    end

    it "returns nil for an incomplete file (no header yet)" do
      Dir.mkdir(File.join(root, project_dir))
      path = File.join(root, project_dir, "partial.jsonl")
      File.write(path, "")
      expect(scanner.upsert_file(path)).to be_nil
    end

    it "keeps manual placement when the file is updated (name change)" do
      path = write_session_file(id: "eee")
      scanner.upsert_file(path)

      card = CardState.find_by!(pi_id: "eee")
      qa = Board.first.columns.find_by!(title: "QA")
      card.update!(column: qa, position: 2)

      # re-upsert same file (append happened)
      scanner.upsert_file(path)
      expect(CardState.find_by!(pi_id: "eee").column.title).to eq("QA")
    end
  end

  describe "#remove_file" do
    it "deletes session and its card states" do
      path = write_session_file(id: "fff")
      scanner.upsert_file(path)

      expect { scanner.remove_file(path) }
        .to change { [SessionRecord.count, CardState.count] }.to([0, 0])
    end
  end
end

RSpec.describe "Board human naming" do
  it "humanizes leaf folder names and keeps path as subtitle" do
    b = Board.new(project_dir: "--Users-chr-projects-conversa-conversa_be--")
    expect(b.human_leaf).to eq("Conversa BE")
    expect(b.short_path).to eq("~/projects/conversa")
  end

  it "names the home directory board Home" do
    b = Board.new(project_dir: "--Users-chr--")
    expect(b.human_leaf).to eq("Home")
    expect(b.short_path).to eq("~")
  end

  it "capitalizes snake_case leaves" do
    expect(Board.new(project_dir: "--Users-chr-projects-chatbot_gems--").human_leaf)
      .to eq("Chatbot Gems")
  end
end

RSpec.describe SessionScanner, "empty project dirs" do
  let(:root) { Dir.mktmpdir("sessions_root") }
  let(:scanner) { described_class.new(root) }

  after { FileUtils.remove_entry(root) }

  it "does not create boards for project dirs without session files" do
    Dir.mkdir(File.join(root, "--Users-chr-conversa--"))
    scanner.full_scan
    expect(Board.count).to eq(0)
  end

  it "drops boards whose project dir lost all sessions" do
    dir = File.join(root, "--Users-chr-x--")
    Dir.mkdir(dir)
    File.write(File.join(dir, "a.jsonl"), {"type" => "session", "id" => "z", "timestamp" => "2026-01-01T00:00:00.000Z", "cwd" => "/x"}.to_json)
    scanner.full_scan
    expect(Board.count).to eq(1)
    File.delete(File.join(dir, "a.jsonl"))
    scanner.full_scan
    expect(Board.count).to eq(0)
  end
end

RSpec.describe SessionScanner, "moved session files" do
  let(:root) { Dir.mktmpdir("sessions_root") }
  let(:scanner) { described_class.new(root) }

  after { FileUtils.remove_entry(root) }

  it "re-assigns a session whose file moved to another project dir" do
    entry = { "type" => "session", "id" => "mv-1", "timestamp" => "2026-01-01T00:00:00.000Z", "cwd" => "/x" }
    Dir.mkdir(File.join(root, "--Users-chr-a--"))
    File.write(File.join(root, "--Users-chr-a--", "s.jsonl"), entry.to_json)
    scanner.full_scan
    expect(SessionRecord.find_by!(pi_id: "mv-1").project_dir).to eq("--Users-chr-a--")

    Dir.mkdir(File.join(root, "--Users-chr-b--"))
    FileUtils.mv(File.join(root, "--Users-chr-a--", "s.jsonl"), File.join(root, "--Users-chr-b--", "s.jsonl"))
    scanner.full_scan

    rec = SessionRecord.find_by!(pi_id: "mv-1")
    expect(rec.project_dir).to eq("--Users-chr-b--")
    expect(rec.file_path).to end_with("--Users-chr-b--/s.jsonl")
    # card moved to the new board
    expect(CardState.find_by!(pi_id: "mv-1").board.project_dir).to eq("--Users-chr-b--")
    # old empty dir's board is dropped
    expect(Board.exists?(project_dir: "--Users-chr-a--")).to be(false)
  end
end

RSpec.describe "AddToDoColumnToExistingBoards data migration" do
  require_relative "../../db/migrate/20260720000003_add_to_do_column_to_existing_boards"

  it "inserts ToDo after Grounding in legacy boards, shifting later columns" do
    board = Board.create!(name: "Legacy", project_dir: "--legacy--")
    %w[Grounding In\ Progress QA Deployed Done].each_with_index do |t, i|
      board.columns.create!(title: t, position: i)
    end

    AddToDoColumnToExistingBoards.new.migrate(:up)

    titles = board.columns.reload.order(:position).map(&:title)
    expect(titles).to eq(%w[Grounding ToDo In\ Progress QA Deployed Done])
  end

  it "is idempotent" do
    board = Board.create!(name: "L2", project_dir: "--l2--").tap(&:ensure_default_columns!)
    expect { AddToDoColumnToExistingBoards.new.migrate(:up) }
      .not_to change { board.columns.reload.count }
  end
end
