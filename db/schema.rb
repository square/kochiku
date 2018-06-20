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

ActiveRecord::Schema.define(version: 20180619210823) do

  create_table "branches", id: :integer, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "repository_id", null: false
    t.string "name", null: false
    t.boolean "convergence", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["repository_id", "convergence"], name: "index_branches_on_repository_id_and_convergence"
    t.index ["repository_id", "name"], name: "index_branches_on_repository_id_and_name", unique: true
    t.index ["repository_id"], name: "index_branches_on_repository_id"
  end

  create_table "build_artifacts", id: :integer, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "build_attempt_id"
    t.string "log_file"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["build_attempt_id"], name: "index_build_artifacts_on_build_attempt_id"
  end

  create_table "build_attempts", id: :integer, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "build_part_id"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.string "builder"
    t.string "state"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "log_streamer_port"
    t.string "instance_type"
    t.index ["build_part_id"], name: "index_build_attempts_on_build_part_id"
    t.index ["created_at"], name: "index_build_attempts_on_created_at"
  end

  create_table "build_parts", id: :integer, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "build_id"
    t.string "kind"
    t.text "paths"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "options"
    t.string "queue"
    t.integer "retry_count", default: 0
    t.index ["build_id"], name: "index_build_parts_on_build_id"
    t.index ["paths"], name: "index_build_parts_on_paths", length: { paths: 255 }
  end

  create_table "builds", id: :integer, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string "ref", limit: 40, null: false
    t.string "state"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "project_id"
    t.boolean "merge_on_success"
    t.boolean "build_failure_email_sent", default: false, null: false
    t.boolean "promoted"
    t.string "on_success_script_log_file"
    t.text "error_details"
    t.boolean "build_success_email_sent", default: false, null: false
    t.integer "branch_id"
    t.string "test_command"
    t.string "initiated_by"
    t.text "kochiku_yml_config"
    t.index ["branch_id"], name: "index_builds_on_branch_id"
    t.index ["project_id"], name: "index_builds_on_project_id"
    t.index ["ref", "branch_id"], name: "index_builds_on_ref_and_branch_id", unique: true
    t.index ["ref", "project_id"], name: "index_builds_on_ref_and_project_id", unique: true
  end

  create_table "projects", id: :integer, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string "name"
    t.string "branch"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "repository_id"
    t.index ["name", "branch"], name: "index_projects_on_name_and_branch"
    t.index ["repository_id"], name: "index_projects_on_repository_id"
  end

  create_table "repositories", id: :integer, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string "url"
    t.string "test_command"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "github_post_receive_hook_id"
    t.boolean "run_ci"
    t.boolean "build_pull_requests"
    t.string "on_green_update"
    t.boolean "send_build_failure_email", default: true, null: false
    t.integer "timeout", default: 40
    t.string "name", null: false
    t.boolean "allows_kochiku_merges", default: true
    t.string "host", null: false
    t.string "namespace"
    t.boolean "send_build_success_email", default: true, null: false
    t.boolean "email_on_first_failure", default: false, null: false
    t.boolean "send_merge_successful_email", default: true, null: false
    t.boolean "enabled", default: true, null: false
    t.integer "assume_lost_after"
    t.index ["host", "namespace", "name"], name: "index_repositories_on_host_and_namespace_and_name", unique: true
    t.index ["namespace", "name"], name: "index_repositories_on_namespace_and_name", unique: true
    t.index ["url"], name: "index_repositories_on_url"
  end

end
