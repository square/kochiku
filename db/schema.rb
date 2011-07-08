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

ActiveRecord::Schema.define(:version => 20110708203120) do

  create_table "build_artifacts", :force => true do |t|
    t.integer  "build_part_result_id"
    t.string   "log_file"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "build_part_results", :force => true do |t|
    t.integer  "build_part_id"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.string   "builder"
    t.string   "state"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "build_parts", :force => true do |t|
    t.integer  "build_id"
    t.string   "kind"
    t.text     "paths"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "builds", :force => true do |t|
    t.string   "sha"
    t.string   "state"
    t.string   "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
