class AddManualTasksAndArchived < ActiveRecord::Migration[8.0]
  def up
    add_column :card_states, :kind, :string, default: "automated", null: false
    add_column :card_states, :title, :string
    add_column :boards, :archived, :boolean, default: false, null: false
    add_index :card_states, :kind
  end

  def down
    remove_index :card_states, :kind
    remove_column :boards, :archived
    remove_column :card_states, :title
    remove_column :card_states, :kind
  end
end
