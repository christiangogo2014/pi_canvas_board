class AddPositionToBoards < ActiveRecord::Migration[8.0]
  def up
    add_column :boards, :position, :integer
    # Backfill preserving the previous alphabetical order
    Board.order(:name).each_with_index { |b, i| b.update_columns(position: i) }
    change_column_null :boards, :position, false
    add_index :boards, :position
  end

  def down
    remove_index :boards, :position
    remove_column :boards, :position
  end
end
