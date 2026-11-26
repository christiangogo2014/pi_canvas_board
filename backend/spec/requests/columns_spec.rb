require "rails_helper"

RSpec.describe "Columns API", type: :request do
  let!(:board) do
    Board.create!(name: "/Users/chr/conversa", project_dir: "--Users-chr-conversa--").tap(&:ensure_default_columns!)
  end
  let(:grounding) { board.columns.find_by!(title: "Grounding") }

  describe "POST /api/boards/:board_id/columns" do
    it "appends a new column at the end" do
      post "/api/boards/#{board.id}/columns", params: { title: "Blocked" }
      expect(response).to have_http_status(:no_content)
      expect(Column.maximum(:position)).to eq(6)
      expect(Column.find_by!(title: "Blocked").position).to eq(6)
    end
  end

  describe "DELETE /api/boards/:board_id/columns/:id" do
    it "returns its cards to the first remaining column" do
      SessionRecord.create!(pi_id: "cx", file_path: "/sessions/x/cx.jsonl",
                            project_dir: board.project_dir,
                            created_at_session: 1.day.ago, updated_at_session: Time.current)
      qa = board.columns.find_by!(title: "QA")
      CardState.create!(board: board, pi_id: "cx", column: qa, position: 0)

      delete "/api/boards/#{board.id}/columns/#{qa.id}"

      expect(response).to have_http_status(:no_content)
      expect(Column.exists?(qa.id)).to be(false)
      expect(CardState.find_by!(pi_id: "cx").column.title).to eq("Grounding")
    end
  end

  describe "PATCH /api/boards/:board_id/columns/:id/reorder" do
    it "changes the column position" do
      qa = board.columns.find_by!(title: "QA")
      patch "/api/boards/#{board.id}/columns/#{qa.id}/reorder", params: { position: 0 }
      expect(response).to have_http_status(:no_content)
      expect(qa.reload.position).to eq(0)
    end
  end

  describe "PATCH /api/boards/:board_id/columns/:id" do
    it "renames the column" do
      patch "/api/boards/#{board.id}/columns/#{grounding.id}", params: { title: "Backlog" }
      expect(response).to have_http_status(:no_content)
      expect(grounding.reload.title).to eq("Backlog")
    end
  end
end
