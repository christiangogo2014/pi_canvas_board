require "rails_helper"

RSpec.describe "Card notes API", type: :request do
  let(:attachments_dir) { Dir.mktmpdir("attachments") }

  before { stub_const("AttachmentStore::ROOT", Pathname.new(attachments_dir)) }
  after { FileUtils.remove_entry(attachments_dir) }

  let!(:board) do
    Board.create!(name: "Conversa", project_dir: "--Users-chr-conversa--").tap(&:ensure_default_columns!)
  end
  let!(:session_record) do
    SessionRecord.create!(pi_id: "note-s1", file_path: "/sessions/x/note-s1.jsonl",
                          project_dir: board.project_dir, name: "Fix login",
                          created_at_session: 1.day.ago, updated_at_session: Time.current)
  end

  describe "GET .../sessions/:pi_id/notes" do
    it "returns session info plus an ordered timeline" do
      session_record.card_notes.create!(kind: "comment", body: "first")
      session_record.card_notes.create!(kind: "description", body: "Fixes the login redirect")
      session_record.card_notes.create!(kind: "comment", body: "second")

      get "/api/boards/#{board.id}/sessions/note-s1/notes"

      notes = json["notes"]
      expect(json.dig("session", "name")).to eq("Fix login")
      expect(notes.map { |n| n["body"] }).to eq(["first", "Fixes the login redirect", "second"])
      expect(notes.map { |n| n["kind"] }.uniq.sort).to eq(%w[comment description])
    end
  end

  describe "POST comment" do
    it "appends a comment" do
      post "/api/boards/#{board.id}/sessions/note-s1/notes",
           params: { kind: "comment", body: "Decided: keep the old endpoint" }, as: :json
      expect(response).to have_http_status(:created)
      expect(CardNote.last.body).to eq("Decided: keep the old endpoint")
    end

    it "rejects empty comments" do
      post "/api/boards/#{board.id}/sessions/note-s1/notes",
           params: { kind: "comment", body: "" }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST description" do
    it "creates or replaces the single description" do
      post "/api/boards/#{board.id}/sessions/note-s1/notes",
           params: { kind: "description", body: "v1" }, as: :json
      post "/api/boards/#{board.id}/sessions/note-s1/notes",
           params: { kind: "description", body: "v2" }, as: :json
      expect(CardNote.where(pi_id: "note-s1", kind: "description").count).to eq(1)
      expect(CardNote.find_by!(pi_id: "note-s1", kind: "description").body).to eq("v2")
    end
  end

  describe "POST attachment (multipart)" do
    it "stores the file and records the note" do
      file = fixture_file_upload("hello.txt", "text/plain")
      post "/api/boards/#{board.id}/sessions/note-s1/notes", params: { file: file }

      note = CardNote.find_by!(pi_id: "note-s1", kind: "attachment")
      expect(note.attachment_filename).to eq("hello.txt")
      expect(File.read(AttachmentStore.path_for("note-s1", "hello.txt"))).to eq("hello world\n")
    end

    it "downloads the stored file again" do
      post "/api/boards/#{board.id}/sessions/note-s1/notes",
           params: { file: fixture_file_upload("hello.txt", "text/plain") }
      note = CardNote.find_by!(kind: "attachment")

      get "/api/attachments/#{note.id}/download"
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("hello world\n")
    end

    it "removes the file when the note is deleted" do
      post "/api/boards/#{board.id}/sessions/note-s1/notes",
           params: { file: fixture_file_upload("hello.txt", "text/plain") }
      note = CardNote.find_by!(kind: "attachment")
      path = AttachmentStore.path_for("note-s1", "hello.txt")
      expect(File.exist?(path)).to be(true)

      delete "/api/notes/#{note.id}"
      expect(File.exist?(path)).to be(false)
      expect(CardNote.exists?(note.id)).to be(false)
    end
  end

  describe "PATCH /api/notes/:id" do
    it "edits a comment body" do
      note = session_record.card_notes.create!(kind: "comment", body: "draft")
      patch "/api/notes/#{note.id}", params: { body: "final decision" }, as: :json
      expect(note.reload.body).to eq("final decision")
    end
  end

  def json
    JSON.parse(response.body)
  end
end
