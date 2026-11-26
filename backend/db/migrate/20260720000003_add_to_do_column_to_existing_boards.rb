class AddToDoColumnToExistingBoards < ActiveRecord::Migration[8.0]
  # Conventional flow: Grounding (intake) → ToDo (ready) → In Progress → …
  # Insert ToDo at position 1 for boards created before this stage existed.
  def up
    Board.find_each do |board|
      next if board.columns.exists?(title: "ToDo")
      board.columns.where("position >= 1").update_all("position = position + 1")
      board.columns.create!(title: "ToDo", position: 1)
    end
  end

  def down
    Column.where(title: "ToDo").find_each(&:destroy)
  end
end
