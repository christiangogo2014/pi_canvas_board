require "rails_helper"

RSpec.describe "Session moves API", type: :request do
  let!(:board) do
    Board.create!(name: "/Users/chr/conversa", project_dir: "--Users-chr-conversa--").tap(&:ensure_default_columns!)
  end
  let(:grounding) { board.columns.find_by!(title: "Grounding") }
  let(:qa) { board.columns.find_by!(title: "QA") }

  def make_card(pi_id:, position: 0)
    SessionRecord.create!(pi_id: pi_id, file_path: "/sessions/x/#{pi_id}.jsonl",
                          project_dir: board.project_dir,
                          created_at_session: 1.day.ago, updated_at_session: Time.current)
    CardState.create!(board: board, pi_id: pi_id, column: grounding, position: position)
  end

  describe "PATCH /api/boards/:board_id/sessions/:id/move" do
    it "moves a card to another column and broadcasts" do
      make_card(pi_id: "mv-1")
      expect(ActionCable.server).to receive(:broadcast)

      patch "/api/boards/#{board.id}/sessions/mv-1/move",
            params: { column_id: qa.id, position: 0 }, as: :json

      expect(response).to have_http_status(:no_content)
      card = CardState.find_by!(pi_id: "mv-1")
      expect(card.column_id).to eq(qa.id)
      expect(card.position).to eq(0)
    end

    it "normalizes positions in source and destination columns" do
      make_card(pi_id: "mv-a", position: 0)
      make_card(pi_id: "mv-b", position: 1)
      make_card(pi_id: "mv-c", position: 2)

      patch "/api/boards/#{board.id}/sessions/mv-a/move",
            params: { column_id: qa.id, position: 0 }, as: :json

      grounding_cards = CardState.where(column: grounding).order(:position)
      expect(grounding_cards.map(&:pi_id)).to eq(%w[mv-b mv-c])
      expect(grounding_cards.map(&:position)).to eq([0, 1])
    end

    it "returns 404 for an unknown card" do
      patch "/api/boards/#{board.id}/sessions/nope/move",
            params: { column_id: qa.id }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
