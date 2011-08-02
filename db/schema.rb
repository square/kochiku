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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20110801215540) do

  create_table "build_artifacts", :force => true do |t|
    t.integer  "build_attempt_id"
    t.string   "log_file"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "build_artifacts", ["build_attempt_id"], :name => "index_build_artifacts_on_build_attempt_id"

  create_table "build_attempts", :force => true do |t|
    t.integer  "build_part_id"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.string   "builder"
    t.string   "state"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "build_attempts", ["build_part_id"], :name => "index_build_attempts_on_build_part_id"

  create_table "build_parts", :force => true do |t|
    t.integer  "build_id"
    t.string   "kind"
    t.text     "paths"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "build_parts", ["build_id"], :name => "index_build_parts_on_build_id"

  create_table "builds", :force => true do |t|
    t.string   "ref"
    t.string   "state"
    t.string   "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "project_id"
  end

  add_index "builds", ["project_id"], :name => "index_builds_on_project_id"

  create_table "projects", :force => true do |t|
    t.string   "name"
    t.string   "branch"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "projects", ["name", "branch"], :name => "index_projects_on_name_and_branch"

end
