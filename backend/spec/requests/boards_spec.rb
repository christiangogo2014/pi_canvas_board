require "rails_helper"

RSpec.describe "Boards API", type: :request do
  let!(:board) do
    Board.create!(name: "/Users/chr/conversa", project_dir: "--Users-chr-conversa--").tap(&:ensure_default_columns!)
  end
  let(:grounding) { board.columns.find_by!(title: "Grounding") }

  def make_card(pi_id:, position: 0)
    SessionRecord.create!(pi_id: pi_id, file_path: "/sessions/x/#{pi_id}.jsonl",
                          project_dir: board.project_dir,
                          name: "Fix login", preview: "fix login",
                          created_at_session: Time.zone.parse("2026-01-01 10:00"),
                          updated_at_session: Time.zone.parse("2026-01-02 10:00"))
    CardState.create!(board: board, pi_id: pi_id, column: grounding, position: position)
  end

  describe "GET /api/boards" do
    it "lists one board per project directory" do
      get "/api/boards"
      expect(response).to have_http_status(:ok)
      expect(json.size).to eq(1)
      expect(json.first).to include("name" => "/Users/chr/conversa", "project_dir" => board.project_dir)
    end
  end

  describe "GET /api/boards/:id" do
    it "returns columns with their cards" do
      make_card(pi_id: "show-1")
      get "/api/boards/#{board.id}"
      expect(response).to have_http_status(:ok)
      ground = json["columns"].find { |c| c["title"] == "Grounding" }
      expect(ground["cards"].size).to eq(1)
      expect(ground["cards"].first).to include("name" => "Fix login", "pi_id" => "show-1")
    end

    it "filters cards by q across name and preview" do
      make_card(pi_id: "q-1", position: 0)
      make_card(pi_id: "q-2", position: 1)
      get "/api/boards/#{board.id}", params: { q: "fix" }
      ground = json["columns"].find { |c| c["title"] == "Grounding" }
      expect(ground["cards"].size).to eq(2)

      get "/api/boards/#{board.id}", params: { q: "nomatch" }
      ground = json["columns"].find { |c| c["title"] == "Grounding" }
      expect(ground["cards"]).to be_empty
    end

    it "applies the board sort within each column" do
      a = make_card(pi_id: "sort-a", position: 0)
      b = make_card(pi_id: "sort-b", position: 1)
      b.session_record.update!(updated_at_session: 1.hour.ago)

      get "/api/boards/#{board.id}" # default: updated_at desc → b (1h ago) before a
      ground = json["columns"].find { |c| c["title"] == "Grounding" }
      expect(ground["cards"].map { |c| c["pi_id"] }).to eq(%w[sort-b sort-a])
    end
  end

  describe "PATCH /api/boards/:id/sort" do
    it "persists the sort field and direction" do
      patch "/api/boards/#{board.id}/sort", params: { sort_field: "created_at_session", sort_dir: "asc" }
      expect(response).to have_http_status(:ok)
      expect(board.reload.sort_field).to eq("created_at_session")
      expect(board.reload.sort_dir).to eq("asc")
    end

    it "rejects unknown sort fields by ignoring them" do
      patch "/api/boards/#{board.id}/sort", params: { sort_field: "evil" }
      expect(response).to have_http_status(:ok)
      expect(board.reload.sort_field).to eq("updated_at_session")
    end
  end

  describe "DELETE /api/boards/:id" do
    it "removes the board" do
      delete "/api/boards/#{board.id}"
      expect(Board.exists?(board.id)).to be(false)
    end
  end

  def json
    JSON.parse(response.body)
  end
end
