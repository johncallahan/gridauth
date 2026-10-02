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

ActiveRecord::Schema[8.1].define(version: 2026_10_02_105655) do
  create_table "gridauth_grid_cards", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "serial", null: false
    t.string "status", default: "pending", null: false
    t.integer "row_count", null: false
    t.integer "column_count", null: false
    t.integer "cell_length", null: false
    t.string "salt", null: false
    t.text "cell_digests", null: false
    t.string "challenge_cells"
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "locked_until"
    t.integer "use_count", default: 0, null: false
    t.datetime "last_used_at"
    t.datetime "activated_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["serial"], name: "index_gridauth_grid_cards_on_serial", unique: true
    t.index ["user_id", "status"], name: "index_gridauth_grid_cards_on_user_id_and_status"
    t.index ["user_id"], name: "index_gridauth_grid_cards_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "gridauth_grid_cards", "users"
  add_foreign_key "sessions", "users"
end
