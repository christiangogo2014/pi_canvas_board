# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_20_000003) do
  create_table "boards", force: :cascade do |t|
    t.string "name", null: false
    t.string "project_dir", null: false
    t.string "sort_field", default: "updated_at_session", null: false
    t.string "sort_dir", default: "desc", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_dir"], name: "index_boards_on_project_dir", unique: true
  end

  create_table "card_notes", force: :cascade do |t|
    t.string "pi_id", null: false
    t.string "kind", default: "comment", null: false
    t.text "body"
    t.string "attachment_filename"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pi_id"], name: "index_card_notes_on_pi_id"
  end

  create_table "card_states", force: :cascade do |t|
    t.integer "board_id", null: false
    t.string "pi_id", null: false
    t.integer "column_id"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["board_id", "pi_id"], name: "index_card_states_on_board_id_and_pi_id", unique: true
    t.index ["board_id"], name: "index_card_states_on_board_id"
    t.index ["column_id"], name: "index_card_states_on_column_id"
  end

  create_table "columns", force: :cascade do |t|
    t.integer "board_id", null: false
    t.string "title", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["board_id"], name: "index_columns_on_board_id"
  end

  create_table "session_records", force: :cascade do |t|
    t.string "pi_id", null: false
    t.string "file_path", null: false
    t.string "project_dir", null: false
    t.string "name"
    t.string "preview"
    t.string "model"
    t.integer "tokens"
    t.decimal "cost", precision: 12, scale: 6
    t.datetime "created_at_session", null: false
    t.datetime "updated_at_session", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["file_path"], name: "index_session_records_on_file_path", unique: true
    t.index ["pi_id"], name: "index_session_records_on_pi_id", unique: true
    t.index ["project_dir"], name: "index_session_records_on_project_dir"
  end
end
