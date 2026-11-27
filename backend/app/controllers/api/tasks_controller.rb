# CRUD for manual task cards: user-created items that live on the board
# without a pi session behind them (kind: "manual", title-based).
module Api
  class TasksController < ApplicationController
    def create
      board = Board.find(params[:board_id])
      column = board.columns.find(params[:column_id])
      board.card_states.create!(
        kind: "manual", title: params[:title], column: column,
        pi_id: "manual-#{SecureRandom.uuid}",
        position: (column.card_states.maximum(:position) || -1) + 1,
      )
      ActionCable.server.broadcast("board:#{board.project_dir}", { "event" => "refresh" })
      head :no_content
    end

    def update
      task = CardState.manual.find_by!(pi_id: params[:id])
      task.update!(title: params[:title])
      broadcast_refresh(task)
      head :no_content
    end

    def destroy
      task = CardState.manual.find_by!(pi_id: params[:id])
      task.destroy
      broadcast_refresh(task)
      head :no_content
    end

    private

    def broadcast_refresh(task)
      dir = task.board.project_dir
      ActionCable.server.broadcast("board:#{dir}", { "event" => "refresh" })
    end
  end
end
