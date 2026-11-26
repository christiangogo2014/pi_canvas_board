class CreateCardNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :card_notes do |t|
      t.string :pi_id, null: false, index: true
      t.string :kind, null: false, default: "comment"
      t.text :body
      t.string :attachment_filename
      t.timestamps
    end
  end
end
