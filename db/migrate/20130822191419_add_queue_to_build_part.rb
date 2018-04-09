class AddQueueToBuildPart < ActiveRecord::Migration[5.1]
  def up
    add_column :build_parts, :queue, :string

    execute("UPDATE build_parts,builds SET build_parts.queue = builds.queue WHERE builds.id = build_parts.build_id")

    remove_column :builds, :queue
    remove_column :repositories, :use_spec_and_ci_queues
  end

  def down
    add_column :repositories, :use_spec_and_ci_queues, :boolean
    add_column :builds, :queue, :string
    remove_column :build_parts, :queue
  end
end
