# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150507153436) do

  create_table "agent_logs", force: :cascade do |t|
    t.integer  "agent_id",          limit: 4,                 null: false
    t.text     "message",           limit: 65535,             null: false, charset: "utf8mb4", collation: "utf8mb4_bin"
    t.integer  "level",             limit: 4,     default: 3, null: false
    t.integer  "inbound_event_id",  limit: 4
    t.integer  "outbound_event_id", limit: 4
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "agents", force: :cascade do |t|
    t.integer  "user_id",               limit: 4
    t.text     "options",               limit: 65535,                                   charset: "utf8mb4", collation: "utf8mb4_bin"
    t.string   "type",                  limit: 191,                                                         collation: "utf8_bin"
    t.string   "name",                  limit: 191,                                     charset: "utf8mb4", collation: "utf8mb4_bin"
    t.string   "schedule",              limit: 191,                                                         collation: "utf8_bin"
    t.integer  "events_count",          limit: 4,          default: 0,     null: false
    t.datetime "last_check_at"
    t.datetime "last_receive_at"
    t.integer  "last_checked_event_id", limit: 4
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "memory",                limit: 4294967295,                              charset: "utf8mb4", collation: "utf8mb4_bin"
    t.datetime "last_web_request_at"
    t.integer  "keep_events_for",       limit: 4,          default: 0,     null: false
    t.datetime "last_event_at"
    t.datetime "last_error_log_at"
    t.boolean  "propagate_immediately", limit: 1,          default: false, null: false
    t.boolean  "disabled",              limit: 1,          default: false, null: false
    t.integer  "service_id",            limit: 4
    t.string   "guid",                  limit: 191,                        null: false
  end

  add_index "agents", ["guid"], name: "index_agents_on_guid", using: :btree
  add_index "agents", ["schedule"], name: "index_agents_on_schedule", using: :btree
  add_index "agents", ["type"], name: "index_agents_on_type", using: :btree
  add_index "agents", ["user_id", "created_at"], name: "index_agents_on_user_id_and_created_at", using: :btree

  create_table "control_links", force: :cascade do |t|
    t.integer  "controller_id",     limit: 4, null: false
    t.integer  "control_target_id", limit: 4, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "control_links", ["control_target_id"], name: "index_control_links_on_control_target_id", using: :btree
  add_index "control_links", ["controller_id", "control_target_id"], name: "index_control_links_on_controller_id_and_control_target_id", unique: true, using: :btree

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer  "priority",   limit: 4,        default: 0
    t.integer  "attempts",   limit: 4,        default: 0
    t.text     "handler",    limit: 16777215,             charset: "utf8mb4", collation: "utf8mb4_bin"
    t.text     "last_error", limit: 65535,                charset: "utf8mb4", collation: "utf8mb4_bin"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by",  limit: 191
    t.string   "queue",      limit: 191
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "delayed_jobs", ["priority", "run_at"], name: "delayed_jobs_priority", using: :btree

  create_table "events", force: :cascade do |t|
    t.integer  "user_id",    limit: 4
    t.integer  "agent_id",   limit: 4
    t.decimal  "lat",                         precision: 15, scale: 10
    t.decimal  "lng",                         precision: 15, scale: 10
    t.text     "payload",    limit: 16777215,                           charset: "utf8mb4", collation: "utf8mb4_bin"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "expires_at"
  end

  add_index "events", ["agent_id", "created_at"], name: "index_events_on_agent_id_and_created_at", using: :btree
  add_index "events", ["expires_at"], name: "index_events_on_expires_at", using: :btree
  add_index "events", ["user_id", "created_at"], name: "index_events_on_user_id_and_created_at", using: :btree

  create_table "links", force: :cascade do |t|
    t.integer  "source_id",            limit: 4
    t.integer  "receiver_id",          limit: 4
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "event_id_at_creation", limit: 4, default: 0, null: false
  end

  add_index "links", ["receiver_id", "source_id"], name: "index_links_on_receiver_id_and_source_id", using: :btree
  add_index "links", ["source_id", "receiver_id"], name: "index_links_on_source_id_and_receiver_id", using: :btree

  create_table "scenario_memberships", force: :cascade do |t|
    t.integer  "agent_id",    limit: 4, null: false
    t.integer  "scenario_id", limit: 4, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "scenario_memberships", ["agent_id"], name: "index_scenario_memberships_on_agent_id", using: :btree
  add_index "scenario_memberships", ["scenario_id"], name: "index_scenario_memberships_on_scenario_id", using: :btree

  create_table "scenarios", force: :cascade do |t|
    t.string   "name",         limit: 191,                   null: false, charset: "utf8mb4", collation: "utf8mb4_bin"
    t.integer  "user_id",      limit: 4,                     null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "description",  limit: 65535,                              charset: "utf8mb4", collation: "utf8mb4_bin"
    t.boolean  "public",       limit: 1,     default: false, null: false
    t.string   "guid",         limit: 191,                   null: false, charset: "ascii",   collation: "ascii_bin"
    t.string   "source_url",   limit: 191
    t.string   "tag_bg_color", limit: 191
    t.string   "tag_fg_color", limit: 191
  end

  add_index "scenarios", ["user_id", "guid"], name: "index_scenarios_on_user_id_and_guid", unique: true, using: :btree

  create_table "services", force: :cascade do |t|
    t.integer  "user_id",       limit: 4,                     null: false
    t.string   "provider",      limit: 191,                   null: false
    t.string   "name",          limit: 191,                   null: false
    t.text     "token",         limit: 65535,                 null: false
    t.text     "secret",        limit: 65535
    t.text     "refresh_token", limit: 65535
    t.datetime "expires_at"
    t.boolean  "global",        limit: 1,     default: false
    t.text     "options",       limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "uid",           limit: 191
  end

  add_index "services", ["provider"], name: "index_services_on_provider", using: :btree
  add_index "services", ["uid"], name: "index_services_on_uid", using: :btree
  add_index "services", ["user_id", "global"], name: "index_services_on_user_id_and_global", using: :btree

  create_table "user_credentials", force: :cascade do |t|
    t.integer  "user_id",          limit: 4,                      null: false
    t.string   "credential_name",  limit: 191,                    null: false
    t.text     "credential_value", limit: 65535,                  null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "mode",             limit: 191,   default: "text", null: false, collation: "utf8_bin"
  end

  add_index "user_credentials", ["user_id", "credential_name"], name: "index_user_credentials_on_user_id_and_credential_name", unique: true, using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "email",                  limit: 191, default: "",    null: false,                     collation: "utf8_bin"
    t.string   "encrypted_password",     limit: 191, default: "",    null: false, charset: "ascii",   collation: "ascii_bin"
    t.string   "reset_password_token",   limit: 191,                                                  collation: "utf8_bin"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          limit: 4,   default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip",     limit: 191
    t.string   "last_sign_in_ip",        limit: 191
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "admin",                  limit: 1,   default: false, null: false
    t.integer  "failed_attempts",        limit: 4,   default: 0
    t.string   "unlock_token",           limit: 191
    t.datetime "locked_at"
    t.string   "username",               limit: 191,                              charset: "utf8mb4", collation: "utf8mb4_unicode_ci"
    t.string   "invitation_code",        limit: 191,                 null: false
    t.integer  "scenario_count",         limit: 4,   default: 0,     null: false
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree
  add_index "users", ["unlock_token"], name: "index_users_on_unlock_token", unique: true, using: :btree
  add_index "users", ["username"], name: "index_users_on_username", unique: true, using: :btree

end
