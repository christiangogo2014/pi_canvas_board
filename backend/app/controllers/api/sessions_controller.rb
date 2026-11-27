module Api
  class SessionsController < ApplicationController
    # Drag & drop: persist the card placement and notify open boards.
    def move
      card = CardState.find_by!(board_id: params[:board_id], pi_id: params[:id])
      column = Column.find(params[:column_id])
      position = params[:position].present? ? params[:position].to_i : nil
      position ||= (column.card_states.maximum(:position) || -1) + 1
      previous_column = card.column
      old_position = card.position

      CardState.transaction do
        if previous_column == column
          # Same column: close the gap at the old slot, then open one at the
          # target (the drag index refers to the list without the dragged card).
          if old_position && position > old_position
            column.card_states.where("position > ? AND position <= ?", old_position, position)
                  .update_all("position = position - 1")
          elsif old_position && position < old_position
            column.card_states.where("position >= ? AND position < ?", position, old_position)
                  .update_all("position = position + 1")
          end
        else
          # Cross column: close the gap in the source, open one in the target.
          if old_position
            previous_column.card_states.where("position > ?", old_position)
                           .update_all("position = position - 1")
          end
          column.card_states.where("position >= ?", position)
                .update_all("position = position + 1")
        end
        card.update!(column: column, position: position)
        normalize_positions!(column)
        normalize_positions!(previous_column) if previous_column && previous_column != column
      end

      notify_board(card.board.project_dir)
      head :no_content
    end

    def rescan
      SessionScanner.new.full_scan
      head :no_content
    end

    # Full conversation tree of one session, for the visual navigator.
    def conversation
      session = SessionRecord.find_by!(pi_id: params[:id])
      return render_json_error("session file missing", status: :not_found) unless File.exist?(session.file_path)

      parsed = ConversationParser.new(session.file_path).call
      render json: { pi_id: session.pi_id, name: session.name, model: session.model,
                     cost: session.cost.to_f, **parsed }
    end

    private

    # Rewrite positions as 0..n-1 in the column's stored order (fallback:
    # board sort order) so drag indexes stay consistent.
    def normalize_positions!(column)
      column.card_states.order(:position, :id).each_with_index do |c, i|
        c.update_columns(position: i) unless c.position == i
      end
    end

    def notify_board(project_dir)
      ActionCable.server.broadcast("board:#{project_dir}", { "event" => "refresh" })
    end
  end
end
