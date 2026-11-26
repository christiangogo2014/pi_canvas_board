class CreateSchema < ActiveRecord::Migration[8.0]
  def change
    create_table :boards do |t|
      t.string :name, null: false
      t.string :project_dir, null: false, index: { unique: true }
      t.string :sort_field, null: false, default: "updated_at_session"
      t.string :sort_dir, null: false, default: "desc"
      t.timestamps
    end

    create_table :columns do |t|
      t.references :board, null: false
      t.string :title, null: false
      t.integer :position, null: false
      t.timestamps
    end

    create_table :session_records do |t|
      t.string :pi_id, null: false, index: { unique: true }
      t.string :file_path, null: false, index: { unique: true }
      t.string :project_dir, null: false, index: true
      t.string :name
      t.string :preview
      t.string :model
      t.integer :tokens
      t.decimal :cost, precision: 12, scale: 6
      t.datetime :created_at_session, null: false
      t.datetime :updated_at_session, null: false
      t.timestamps
    end

    create_table :card_states do |t|
      t.references :board, null: false
      t.string :pi_id, null: false
      t.references :column
      t.integer :position
      t.timestamps
      t.index [:board_id, :pi_id], unique: true
    end
  end
end
