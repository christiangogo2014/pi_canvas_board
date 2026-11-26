module Api
  class ColumnsController < ApplicationController
    before_action :set_board

    def create
      position = (@board.columns.maximum(:position) || -1) + 1
      @board.columns.create!(title: params[:title], position: position)
      head :no_content
    end

    def update
      @column = @board.columns.find(params[:id])
      @column.update!(column_params)
      head :no_content
    end

    def reorder
      @column = @board.columns.find(params[:id])
      @column.update!(position: params[:position].to_i)
      head :no_content
    end

    def destroy
      @column = @board.columns.find(params[:id])
      # Cards return to the first remaining column rather than vanishing
      first_remaining = @board.columns.where.not(id: @column.id).order(:position).first
      CardState.where(column: @column).find_each do |card|
        card.update!(column: first_remaining,
                     position: (first_remaining&.card_states&.maximum(:position) || -1) + 1)
      end
      @column.destroy
      head :no_content
    end

    private

    def set_board
      @board = Board.find(params[:board_id])
    end

    def column_params
      params.permit(:title)
    end
  end
end
