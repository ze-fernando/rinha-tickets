ActiveRecord::Schema[8.1].define(version: 2026_10_24_204521) do
  create_table "tickets", force: :cascade do |t|
    t.string "title", null: false
    t.text "description", null: false
    t.string "sector", null: false
    t.string "status", default: "open", null: false
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["title"], name: "index_tickets_on_title", unique: true
    t.check_constraint "status IN ('open', 'in_progress', 'closed')", name: "tickets_status_check"
  end
end
