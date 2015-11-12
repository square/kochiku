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

ActiveRecord::Schema.define(version: 20151111080255) do

  create_table "branches", force: :cascade do |t|
    t.integer  "repository_id", limit: 4,                   null: false
    t.string   "name",          limit: 255,                 null: false
    t.boolean  "convergence",               default: false, null: false
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
  end

  add_index "branches", ["convergence"], name: "index_branches_on_convergence", using: :btree
  add_index "branches", ["repository_id", "name"], name: "index_branches_on_repository_id_and_name", unique: true, using: :btree

  create_table "build_artifacts", force: :cascade do |t|
    t.integer  "build_attempt_id", limit: 4
    t.string   "log_file",         limit: 255
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
  end

  add_index "build_artifacts", ["build_attempt_id"], name: "index_build_artifacts_on_build_attempt_id", using: :btree

  create_table "build_attempts", force: :cascade do |t|
    t.integer  "build_part_id",     limit: 4
    t.datetime "started_at"
    t.datetime "finished_at"
    t.string   "builder",           limit: 255
    t.string   "state",             limit: 255
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
    t.integer  "log_streamer_port", limit: 4
  end

  add_index "build_attempts", ["build_part_id"], name: "index_build_attempts_on_build_part_id", using: :btree

  create_table "build_parts", force: :cascade do |t|
    t.integer  "build_id",    limit: 4
    t.string   "kind",        limit: 255
    t.text     "paths",       limit: 65535
    t.datetime "created_at",                            null: false
    t.datetime "updated_at",                            null: false
    t.text     "options",     limit: 65535
    t.string   "queue",       limit: 255
    t.integer  "retry_count", limit: 4,     default: 0
  end

  add_index "build_parts", ["build_id"], name: "index_build_parts_on_build_id", using: :btree
  add_index "build_parts", ["paths"], name: "index_build_parts_on_paths", length: {"paths"=>255}, using: :btree

  create_table "builds", force: :cascade do |t|
    t.string   "ref",                        limit: 40,                    null: false
    t.string   "state",                      limit: 255
    t.datetime "created_at",                                               null: false
    t.datetime "updated_at",                                               null: false
    t.integer  "project_id",                 limit: 4
    t.boolean  "merge_on_success"
    t.boolean  "build_failure_email_sent",                 default: false, null: false
    t.boolean  "promoted"
    t.string   "on_success_script_log_file", limit: 255
    t.text     "error_details",              limit: 65535
    t.boolean  "build_success_email_sent",                 default: false, null: false
    t.integer  "branch_id",                  limit: 4
  end

  add_index "builds", ["branch_id"], name: "index_builds_on_branch_id", using: :btree
  add_index "builds", ["project_id"], name: "index_builds_on_project_id", using: :btree
  add_index "builds", ["ref", "branch_id"], name: "index_builds_on_ref_and_branch_id", unique: true, using: :btree
  add_index "builds", ["ref", "project_id"], name: "index_builds_on_ref_and_project_id", unique: true, using: :btree

  create_table "projects", force: :cascade do |t|
    t.string   "name",          limit: 255
    t.string   "branch",        limit: 255
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.integer  "repository_id", limit: 4
  end

  add_index "projects", ["name", "branch"], name: "index_projects_on_name_and_branch", using: :btree
  add_index "projects", ["repository_id"], name: "index_projects_on_repository_id", using: :btree

  create_table "repositories", force: :cascade do |t|
    t.string   "url",                         limit: 255
    t.string   "test_command",                limit: 255
    t.datetime "created_at",                                              null: false
    t.datetime "updated_at",                                              null: false
    t.integer  "github_post_receive_hook_id", limit: 4
    t.boolean  "run_ci"
    t.boolean  "build_pull_requests"
    t.string   "on_green_update",             limit: 255
    t.boolean  "send_build_failure_email",                default: true,  null: false
    t.integer  "timeout",                     limit: 4,   default: 40
    t.string   "name",                        limit: 255,                 null: false
    t.boolean  "allows_kochiku_merges",                   default: true
    t.string   "host",                        limit: 255,                 null: false
    t.string   "namespace",                   limit: 255
    t.boolean  "send_build_success_email",                default: true,  null: false
    t.boolean  "email_on_first_failure",                  default: false, null: false
    t.boolean  "send_merge_successful_email",             default: true,  null: false
  end

  add_index "repositories", ["host", "namespace", "name"], name: "index_repositories_on_host_and_namespace_and_name", unique: true, using: :btree
  add_index "repositories", ["namespace", "name"], name: "index_repositories_on_namespace_and_name", unique: true, using: :btree
  add_index "repositories", ["url"], name: "index_repositories_on_url", using: :btree

end
