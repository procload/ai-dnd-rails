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

ActiveRecord::Schema[8.0].define(version: 2025_02_07_152423) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "characters", force: :cascade do |t|
    t.string "name"
    t.string "class_type"
    t.integer "level"
    t.string "alignment"
    t.jsonb "ability_scores"
    t.jsonb "personality_traits", default: "[]", null: false
    t.jsonb "equipment", default: "{\"weapons\":[],\"armor\":[],\"adventuring_gear\":[]}", null: false
    t.jsonb "spells", default: "{\"cantrips\":[],\"level_1_spells\":[]}", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "background"
    t.check_constraint "equipment ? 'weapons'::text AND equipment ? 'armor'::text AND equipment ? 'adventuring_gear'::text", name: "equipment_required_keys_check"
    t.check_constraint "jsonb_array_length(equipment -> 'weapons'::text) >= 0 AND jsonb_array_length(equipment -> 'weapons'::text) <= 4 AND jsonb_array_length(equipment -> 'armor'::text) >= 0 AND jsonb_array_length(equipment -> 'armor'::text) <= 2 AND jsonb_array_length(equipment -> 'adventuring_gear'::text) >= 0 AND jsonb_array_length(equipment -> 'adventuring_gear'::text) <= 8", name: "equipment_arrays_length_check"
    t.check_constraint "jsonb_array_length(personality_traits) >= 0 AND jsonb_array_length(personality_traits) <= 4", name: "personality_traits_length_check"
    t.check_constraint "jsonb_array_length(spells -> 'cantrips'::text) >= 0 AND jsonb_array_length(spells -> 'cantrips'::text) <= 4 AND jsonb_array_length(spells -> 'level_1_spells'::text) >= 0 AND jsonb_array_length(spells -> 'level_1_spells'::text) <= 4", name: "spells_arrays_length_check"
    t.check_constraint "spells ? 'cantrips'::text AND spells ? 'level_1_spells'::text", name: "spells_required_keys_check"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
end
