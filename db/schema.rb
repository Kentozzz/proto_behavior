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

ActiveRecord::Schema[8.1].define(version: 2025_10_24_121714) do
  create_table "check_results", force: :cascade do |t|
    t.string "check_number"
    t.integer "check_session_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.text "note"
    t.integer "section_number"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["check_session_id"], name: "index_check_results_on_check_session_id"
  end

  create_table "check_sessions", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "started_at"
    t.string "status"
    t.string "target_url"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "check_results", "check_sessions"
end
