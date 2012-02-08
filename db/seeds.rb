Project.delete_all

web = Project.create!({:name => 'web', :branch => 'master', :created_at => "2011-07-20 19:21:01", :updated_at => "2011-07-20 19:21:01"})

build = Build.create!({:project => web, :ref => "3abd03269b65d9dc6c92345951e4929cd50b7e61", :state => "succeeded", :queue => "ci", :created_at => "2011-09-21 19:39:51", :updated_at => "2011-09-21 19:39:51"})

build_part1 = build.build_parts.create!({:kind => "cucumber", :paths => ["features/authenticated/activate/bank_account.feature", "features/api/v1/transfer.feature"], :created_at => "2011-09-21 19:40:04", :updated_at => "2011-09-21 19:40:04"})
build_part2 = build.build_parts.create!({:kind => "spec", :paths => ["spec/lint", "spec/views", "spec/lib", "spec/models/permission_spec.rb", "spec/models/user", "spec/models/user_spec.rb"], :created_at => "2011-09-21 19:40:04", :updated_at => "2011-09-21 19:40:06"})

build_part1.build_attempts.create!({:started_at => "2011-09-21 19:40:14", :finished_at => "2011-09-21 19:41:16", :builder => "macbuild07.local", :state => "passed", :created_at => "2011-09-21 19:40:14", :updated_at => "2011-09-21 19:41:16"})
build_part2.build_attempts.create!({:started_at => "2011-09-21 19:40:14", :finished_at => "2011-09-21 19:41:16", :builder => "macbuild08.local", :state => "passed", :created_at => "2011-09-21 19:40:14", :updated_at => "2011-09-21 19:41:16"})



build = Build.create!({:project => web, :ref => "6223e7e3356d24b1c98e02986dcb576c2c7e9999", :state => "running", :queue => "ci"})
build_part1 = build.build_parts.create!({:kind => "cucumber", :paths => ["features/authenticated/activate/bank_account.feature", "features/api/v1/transfer.feature"]})
started = Time.now - 2.minutes
build_part1.build_attempts.create!({:started_at => started, :builder => "macbuild07.local", :state => "running", :created_at => started})
