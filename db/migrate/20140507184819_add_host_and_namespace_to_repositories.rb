class AddHostAndNamespaceToRepositories < ActiveRecord::Migration[5.1]
  def up
    rename_column :repositories, :repository_name, :name
    change_column :repositories, :name, :string, null: false  # add not null constraint
    add_column :repositories, :host, :string, null: false
    add_column :repositories, :namespace, :string, null: true  # generic git servers will not have a namespace

    add_index :repositories, [:host, :namespace, :name],
              name: 'index_repositories_on_host_and_namespace_and_name',
              unique: true

    Repository.all.each do |repository|
      attributes = RemoteServer.for_url(repository.url).attributes
      repository.update_attributes!(
        :host => attributes.fetch(:host),
        :namespace => attributes.fetch(:repository_namespace)
      )
    end
  end

  def down
    remove_index :repositories, name: 'index_repositories_on_host_and_namespace_and_name'
    remove_columns :repositories, :namespace, :host
    change_column :repositories, :name, :string, null: true
    rename_column :repositories, :name, :repository_name
  end
end
