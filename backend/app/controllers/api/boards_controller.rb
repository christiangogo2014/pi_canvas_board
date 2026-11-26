module Api
  class BoardsController < ApplicationController
    def index
      render json: Board.ordered.as_json(methods: %i[project_path short_path],
                                          only: %i[id name project_dir sort_field sort_dir position])
    end

    def show
      board = Board.find(params[:id])
      render json: board_json(board)
    end

    def update
      board = Board.find(params[:id])
      if params.dig(:board, :name).present?
        board.update!(board_params)
      else
        board.update!(sort_params)
      end
      render json: board_json(board)
    end

    def destroy
      Board.find(params[:id]).destroy
      head :no_content
    end

    def sort
      board = Board.find(params[:id])
      board.update!(sort_params)
      render json: board_json(board)
    end

    # Persist the drag & drop order of the board tiles (one request for all).
    def reorder
      ids = Array(params[:order]).map(&:to_i)
      Board.transaction do
        ids.each_with_index { |id, i| Board.find(id).update!(position: i) }
      end
      head :no_content
    rescue ActiveRecord::RecordNotFound
      render_json_error("unknown board id", status: :not_found)
    end

    private

    def board_params
      params.require(:board).permit(:name)
    end

    def sort_params
      p = {}
      field = params[:sort_field]
      p[:sort_field] = field if Board::SORT_FIELDS.include?(field)
      dir = params[:sort_dir]
      p[:sort_dir] = dir if %w[asc desc].include?(dir)
      p
    end

    def board_json(board)
      cards = board.columns.ordered.to_h { |col| [col.id, BoardCardsQuery.new(board, col, params[:q]).call] }
      {
        id: board.id, name: board.name, project_dir: board.project_dir,
        project_path: board.project_path, short_path: board.short_path,
        sort_field: board.sort_field, sort_dir: board.sort_dir,
        columns: board.columns.ordered.map do |col|
          {
            id: col.id, title: col.title, position: col.position,
            cards: cards[col.id].map { |s| session_json(s) }
          }
        end
      }
    end

    def session_json(s)
      {
        pi_id: s.pi_id, name: s.name, preview: s.preview, model: s.model,
        tokens: s.tokens, cost: s.cost.to_f,
        created_at_session: s.created_at_session&.utc&.iso8601,
        updated_at_session: s.updated_at_session&.utc&.iso8601
      }
    end
  end

  # Assembles the card list of one column, with optional search filtering,
  # in the board's configured sort order.
  class BoardCardsQuery
    def initialize(board, column, query)
      @board = board
      @column = column
      @query = query.presence
    end

    def call
      scope = SessionRecord.joins(:card_states)
                           .where(card_states: { board_id: @board.id, column_id: @column.id })
      scope = search(scope) if @query
      scope.order(Arel.sql("#{@board.sort_field} #{@board.sort_dir}"), "card_states.position ASC")
    end

    private

    def search(scope)
      q = "%#{@query}%"
      t = SessionRecord.arel_table
      scope.where(t[:name].matches(q).or(t[:preview].matches(q)))
    end
  end
end
