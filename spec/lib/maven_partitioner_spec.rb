require 'spec_helper'

describe MavenPartitioner do
  let(:repository) { FactoryGirl.create(:repository, :url => "git@git.squareup.com:square/java.git") }
  let(:project) { FactoryGirl.create(:project, :repository => repository, :name => repository.repository_name) }
  let(:build) { FactoryGirl.create(:build, :queue => :developer, :project => project, :branch => "master") }

  subject { MavenPartitioner.new(build) }

  describe "#group_modules" do
    it "should group modules based on the top level directory" do
      subject.stub(:deployable_modules_map).and_return({})
      modules = ["a", "b", "b/1", "b/2", "b/1/2", "c/1"]
      partitions = subject.group_modules(modules)
      partitions.size.should == 3
      partitions.should include({"type" => "maven", "files" => ["a"], "upload_artifacts" => false})
      partitions.should include({"type" => "maven", "files" => ["b", "b/1", "b/2", "b/1/2"], "upload_artifacts" => false})
      partitions.should include({"type" => "maven", "files" => ["c/1"], "upload_artifacts" => false})
    end
  end

  describe "#incremental_partitions" do
    context "on master as the main build for the project" do
      it "should be the main build" do
        build.project.should be_main
      end

      it "should return the set of modules to build for a given set of file changes" do
        GitBlame.stub(:files_changed_since_last_green).with(build).and_return([{:file => "module-one/src/main/java/com/squareup/foo.java", :emails => []},
                                                                               {:file => "module-two/src/main/java/com/squareup/bar.java", :emails => []}])
        File.stub(:exists?).and_return(false)
        File.stub(:exists?).with("module-one/pom.xml").and_return(true)
        File.stub(:exists?).with("module-two/pom.xml").and_return(true)

        subject.stub(:maven_modules).and_return(["module-one", "module-two", "module-two/integration", "module-three", "module-four"])
        subject.stub(:depends_on_map).and_return({
                                                   "module-one" => ["module-one", "module-three", "module-four"].to_set,
                                                   "module-two" => ["module-two", "module-two/integration", "module-three"].to_set,
                                                 })
        subject.stub(:deployable_modules_map).and_return({"module-four" => {}})
        subject.should_not_receive(:partitions)

        partitions = subject.incremental_partitions
        partitions.size.should == 5
        partitions.should include({"type" => "maven", "files" => ["all-java"], "upload_artifacts" => false})
        partitions.should include({"type" => "maven", "files" => ["module-one"], "upload_artifacts" => false})
        partitions.should include({"type" => "maven", "files" => ["module-two", "module-two/integration"], "upload_artifacts" => false})
        partitions.should include({"type" => "maven", "files" => ["module-three"], "upload_artifacts" => false})
        partitions.should include({"type" => "maven", "files" => ["module-four"], "upload_artifacts" => true})
      end

      it "should build everything if one of the files does not map to a module" do
        GitBlame.stub(:files_changed_since_last_green).with(build).and_return([{:file => "toplevel/foo.xml", :emails => []}])

        subject.stub(:depends_on_map).and_return({
                                                  "module-one" => ["module-one", "module-three", "module-four"].to_set,
                                                  "module-two" => ["module-two", "module-three"].to_set
                                                 })

        subject.should_receive(:partitions).and_return([{"type" => "maven", "files" => "ALL"}])

        partitions = subject.incremental_partitions
        partitions.should == [{"type" => "maven", "files" => "ALL"}]
      end

      it "should not build everything if the file change is from the all-protos subtree and ends in .proto" do
        GitBlame.stub(:files_changed_since_last_green).with(build).and_return([{:file => "squareup/juno/internal.proto", :emails => []},
                                                                              {:file => "module-two/src/main/java/com/squareup/bar.java", :emails => []}])
        File.stub(:exists?).and_return(false)
        File.stub(:exists?).with("module-two/pom.xml").and_return(true)

        subject.stub(:maven_modules).and_return(["module-one", "module-two"])
        subject.stub(:depends_on_map).and_return({ "module-two" => ["module-two"].to_set })
        subject.stub(:deployable_modules_map).and_return({})
        subject.should_not_receive(:partitions)

        partitions = subject.incremental_partitions
        partitions.size.should == 3
        partitions.should include({"type" => "maven", "files" => ["all-java"], "upload_artifacts" => false})
        partitions.should include({"type" => "maven", "files" => ["all-protos"], "upload_artifacts" => false})
        partitions.should include({"type" => "maven", "files" => ["module-two"], "upload_artifacts" => false})
      end

      it "should not build everything if the file change is from the .rig or .hoist directory or the toplevel pom.xml" do
        GitBlame.stub(:files_changed_since_last_green).with(build).and_return([{:file => ".rig/test", :emails => []},
                                                                               {:file => ".hoist/test", :emails => []},
                                                                               {:file => "pom.xml", :emails => []},
                                                                               {:file => "module-two/src/main/java/com/squareup/bar.java", :emails => []}])
        File.stub(:exists?).and_return(false)
        File.stub(:exists?).with("module-two/pom.xml").and_return(true)

        subject.stub(:maven_modules).and_return(["module-one", "module-two"])
        subject.stub(:depends_on_map).and_return({ "module-two" => ["module-two"].to_set })
        subject.stub(:deployable_modules_map).and_return({})

        subject.should_not_receive(:partitions)

        partitions = subject.incremental_partitions
        partitions.size.should == 2
        partitions.should include({"type" => "maven", "files" => ["all-java"], "upload_artifacts" => false})
        partitions.should include({"type" => "maven", "files" => ["module-two"], "upload_artifacts" => false})
      end

      it "should not fail if a file is reference in a top level module that is not in the top level pom" do
        GitBlame.stub(:files_changed_since_last_green).with(build).and_return([{:file => "new-module/src/main/java/com/squareup/foo.java", :emails => []}])

        File.stub(:exists?).and_return(false)
        File.stub(:exists?).with("new-module/pom.xml").and_return(true)

        subject.stub(:maven_modules).and_return(["module-one", "module-two"])
        subject.stub(:depends_on_map).and_return({
                                                  "module-one" => ["module-one", "module-three", "module-four"].to_set,
                                                  "module-two" => ["module-two", "module-three"].to_set
                                                 })
        subject.stub(:deployable_modules_map).and_return({})
        subject.should_not_receive(:partitions)

        partitions = subject.incremental_partitions
        partitions.size.should == 1
        partitions.should include({"type" => "maven", "files" => ["all-java"], "upload_artifacts" => false})
      end
    end

    context "on a branch" do
      let(:build) { FactoryGirl.create(:build, :queue => :developer, :branch => "branch-of-master") }

      it "should not be the main build" do
        build.project.should_not be_main
      end

      it "should return the set of modules to build for a given set of file changes" do
        GitBlame.stub(:files_changed_in_branch).with(build).and_return([{:file => "module-one/src/main/java/com/squareup/foo.java", :emails => []},
                                                                        {:file => "module-two/src/main/java/com/squareup/bar.java", :emails => []}])
        File.stub(:exists?).and_return(false)
        File.stub(:exists?).with("module-one/pom.xml").and_return(true)
        File.stub(:exists?).with("module-two/pom.xml").and_return(true)

        subject.stub(:maven_modules).and_return(["module-one", "module-two", "module-three", "module-four"])
        subject.stub(:depends_on_map).and_return({
                                                   "module-one" => ["module-three", "module-four"].to_set,
                                                   "module-two" => ["module-three"].to_set
                                                 })
        subject.stub(:deployable_modules_map).and_return({})
        subject.should_not_receive(:partitions)

        partitions = subject.incremental_partitions
        partitions.size.should == 2
        partitions.should include({"type" => "maven", "files" => ["module-three"], "upload_artifacts" => false})
        partitions.should include({"type" => "maven", "files" => ["module-four"], "upload_artifacts" => false})
      end

      it "should build everything if one of the files does not map to a module" do
        GitBlame.stub(:files_changed_in_branch).with(build).and_return([{:file => "toplevel/foo.xml", :emails => []}])

        subject.stub(:depends_on_map).and_return({
                                                   "module-one" => ["module-three", "module-four"].to_set,
                                                   "module-two" => ["module-three"].to_set
                                                 })

        subject.should_receive(:partitions).and_return([{"type" => "maven", "files" => "ALL"}])

        partitions = subject.incremental_partitions
        partitions.should == [{"type" => "maven", "files" => "ALL"}]
      end

      it "should not fail if a file is reference in a top level module that is not in the top level pom" do
        GitBlame.stub(:files_changed_in_branch).with(build).and_return([{:file => "new-module/src/main/java/com/squareup/foo.java", :emails => []}])

        File.stub(:exists?).and_return(false)
        File.stub(:exists?).with("new-module/pom.xml").and_return(true)

        subject.stub(:depends_on_map).and_return({
                                                   "module-one" => ["module-three", "module-four"].to_set,
                                                   "module-two" => ["module-three"].to_set
                                                 })
        subject.should_not_receive(:partitions)

        partitions = subject.incremental_partitions
        partitions.should be_empty
      end
    end
  end

  describe "#emails_for_commits_causing_failures" do
    it "should return nothing if there are no failed parts" do
      build.build_parts.failed_or_errored.should be_empty
      emails = subject.emails_for_commits_causing_failures
      emails.should be_empty
    end

    it "should return the emails for the modules that are failing" do
      build_part = FactoryGirl.create(:build_part, :paths => ["module-four"], :build_instance => build)
      FactoryGirl.create(:build_attempt, :state => :failed, :build_part => build_part)
      build.build_parts.failed_or_errored.should == [build_part]

      GitRepo.stub(:inside_copy).and_yield
      GitBlame.stub(:files_changed_since_last_green).with(build, :fetch_emails => true).and_return([{:file => "module-one/src/main/java/com/squareup/Foo.java", :emails => ["userone@example.com"]},
                                                                             {:file => "module-two/src/main/java/com/squareup/Bar.java", :emails => ["usertwo@example.com"]},
                                                                             {:file => "module-four/src/main/java/com/squareup/Baz.java", :emails => ["userfour@example.com"]},
                                                                             {:file => "module-four/src/main/java/com/squareup/Bing.java", :emails => ["userfour@example.com"]}])
      File.stub(:exists?).and_return(false)
      File.stub(:exists?).with("module-one/pom.xml").and_return(true)
      File.stub(:exists?).with("module-two/pom.xml").and_return(true)
      File.stub(:exists?).with("module-four/pom.xml").and_return(true)

      subject.stub(:depends_on_map).and_return({
                                                   "module-one" => ["module-one", "module-three", "module-four"].to_set,
                                                   "module-two" => ["module-two", "module-three"].to_set,
                                                   "module-four" => ["module-four"].to_set
                                               })
      subject.should_not_receive(:partitions)

      email_and_files = subject.emails_for_commits_causing_failures
      email_and_files.size.should == 2
      email_and_files["userone@example.com"].should == ["module-one/src/main/java/com/squareup/Foo.java"]
      email_and_files["userfour@example.com"].size.should == 2
      email_and_files["userfour@example.com"].should include("module-four/src/main/java/com/squareup/Baz.java")
      email_and_files["userfour@example.com"].should include("module-four/src/main/java/com/squareup/Bing.java")
    end

    it "should ignore changes in the all-protos subtree module if all-protos doesn't fail" do
      build_part = FactoryGirl.create(:build_part, :paths => ["module-one"], :build_instance => build)
      FactoryGirl.create(:build_attempt, :state => :failed, :build_part => build_part)
      protos_part = FactoryGirl.create(:build_part, :paths => ["all-protos"], :build_instance => build)
      FactoryGirl.create(:build_attempt, :state => :passed, :build_part => protos_part)
      build.build_parts.failed_or_errored.should == [build_part]

      GitRepo.stub(:inside_copy).and_yield
      GitBlame.stub(:files_changed_since_last_green).with(build, :fetch_emails => true).and_return([{:file => "module-one/src/main/java/com/squareup/Foo.java", :emails => ["userone@example.com"]},
                                                                                                   {:file => "squareup/juno/internal.proto", :emails => ["protouser@example.com"]}])
      File.stub(:exists?).and_return(false)
      File.stub(:exists?).with("module-one/pom.xml").and_return(true)

      subject.stub(:depends_on_map).and_return({ "module-one" => ["module-one"].to_set })
      subject.should_not_receive(:partitions)

      email_and_files = subject.emails_for_commits_causing_failures
      email_and_files.size.should == 1
      email_and_files["userone@example.com"].should ==["module-one/src/main/java/com/squareup/Foo.java"]
    end

    it "should email changes to all-protos subtree module if all-protos fails" do
      build_part = FactoryGirl.create(:build_part, :paths => ["module-one"], :build_instance => build)
      FactoryGirl.create(:build_attempt, :state => :failed, :build_part => build_part)
      protos_part = FactoryGirl.create(:build_part, :paths => ["all-protos"], :build_instance => build)
      FactoryGirl.create(:build_attempt, :state => :failed, :build_part => protos_part)
      build.build_parts.failed_or_errored.should == [build_part, protos_part]

      GitRepo.stub(:inside_copy).and_yield
      GitBlame.stub(:files_changed_since_last_green).with(build, :fetch_emails => true).and_return([{:file => "module-one/src/main/java/com/squareup/Foo.java", :emails => ["userone@example.com"]},
                                                                                                    {:file => "squareup/juno/internal.proto", :emails => ["protouser@example.com"]}])
      File.stub(:exists?).and_return(false)
      File.stub(:exists?).with("module-one/pom.xml").and_return(true)

      subject.stub(:depends_on_map).and_return({ "module-one" => ["module-one"].to_set })
      subject.should_not_receive(:partitions)

      email_and_files = subject.emails_for_commits_causing_failures
      email_and_files.size.should == 2
      email_and_files["userone@example.com"].should ==["module-one/src/main/java/com/squareup/Foo.java"]
      email_and_files["protouser@example.com"].should ==["squareup/juno/internal.proto"]
    end

    it "should not ignore changes in the .rig directory" do
      build_part = FactoryGirl.create(:build_part, :paths => ["module-one"], :build_instance => build)
      FactoryGirl.create(:build_attempt, :state => :failed, :build_part => build_part)
      build.build_parts.failed_or_errored.should == [build_part]

      GitRepo.stub(:inside_copy).and_yield
      GitBlame.stub(:files_changed_since_last_green).with(build, :fetch_emails => true).and_return([{:file => ".rig/build_keywhiz", :emails => ["riguser@example.com"]}])
      File.stub(:exists?).and_return(false)

      subject.stub(:depends_on_map).and_return({ "module-one" => ["module-one"].to_set })
      subject.should_not_receive(:partitions)

      email_and_files = subject.emails_for_commits_causing_failures
      email_and_files.should be_empty
    end
  end

  describe "#depends_on_map" do
    it "should convert a dependency map to a depends on map" do
      subject.stub(:module_dependency_map).and_return({
                                                        "module-one" => ["a", "b", "c"].to_set,
                                                        "module-two" => ["b", "c", "module-one"].to_set,
                                                        "module-three" => Set.new
                                                      })

      depends_on_map = subject.depends_on_map

      depends_on_map["module-one"].should == ["module-one", "module-two"].to_set
      depends_on_map["module-two"].should == ["module-two"].to_set
      depends_on_map["module-three"].should == ["module-three"].to_set
      depends_on_map["a"].should == ["a", "module-one"].to_set
      depends_on_map["b"].should == ["b", "module-one", "module-two"].to_set
      depends_on_map["c"].should == ["c", "module-one", "module-two"].to_set
      depends_on_map["all-protos"].should be_nil
    end

    it "should special case the all-protos dependency" do
      subject.stub(:module_dependency_map).and_return({
                                                          "module-one" => ["all-protos"].to_set,
                                                          "module-two" => ["all-protos"].to_set,
                                                          "all-protos" => Set.new
                                                      })

      depends_on_map = subject.depends_on_map
      depends_on_map["all-protos"].should == ["all-protos"].to_set
    end
  end

  context "with actual files" do

    let(:top_level_pom) { <<-POM
<project>
  <modules>
    <module>module-one</module>
    <module>module-two</module>
    <module>module-three</module>
  </modules>
</project>
    POM
    }

    let(:module_one_pom) { <<-POM
<project>
  <properties>
    <deployableBranch>one-branch</deployableBranch>
  </properties>

  <groupId>com.squareup</groupId>
  <artifactId>module-core</artifactId>

  <dependencies>
    <dependency>
      <groupId>com.squareup</groupId>
      <artifactId>module-extras</artifactId>
    </dependency>
    <dependency>
      <groupId>junit</groupId>
      <artifactId>junit</artifactId>
    </dependency>
  </dependencies>
</project>
    POM
    }

    let(:module_two_pom) { <<-POM
<project>
  <properties>
    <deployableBranch>two-branch</deployableBranch>
  </properties>

  <groupId>com.squareup</groupId>
  <artifactId>module-extras</artifactId>

  <dependencies>
    <dependency>
      <groupId>com.squareup</groupId>
      <artifactId>module-three</artifactId>
    </dependency>
  </dependencies>
</project>
    POM
    }

    let(:module_three_pom) { <<-POM
<project>
  <groupId>com.squareup</groupId>
  <artifactId>module-three</artifactId>

  <dependencies>
    <dependency>
      <groupId>junit</groupId>
      <artifactId>junit</artifactId>
    </dependency>
  </dependencies>
</project>
    POM
    }

    describe "#module_dependency_map" do
      it "it should get the transitive dependencies from a pom" do
        File.stub(:read).with(MavenPartitioner::POM_XML).and_return(top_level_pom)
        File.stub(:read).with("module-one/pom.xml").and_return(module_one_pom)
        File.stub(:read).with("module-two/pom.xml").and_return(module_two_pom)
        File.stub(:read).with("module-three/pom.xml").and_return(module_three_pom)

        dependency_map = subject.module_dependency_map

        dependency_map["module-one"].should == ["module-one", "module-two", "module-three"].to_set
        dependency_map["module-two"].should == ["module-two", "module-three"].to_set
        dependency_map["module-three"].should == ["module-three"].to_set
      end
    end

    describe "#deployable_modules_map" do
      it "it should get the deployable branches from the poms" do
        File.stub(:read).with(MavenPartitioner::POM_XML).and_return(top_level_pom)
        File.stub(:read).with("module-one/pom.xml").and_return(module_one_pom)
        File.stub(:read).with("module-two/pom.xml").and_return(module_two_pom)
        File.stub(:read).with("module-three/pom.xml").and_return(module_three_pom)

        subject.deployable_modules_map.should == {
          "module-one"=>"one-branch",
          "module-two"=>"two-branch"
        }
      end
    end
  end

  describe "#transitive_dependencies" do
    it "should return the module in a set as a base case" do
      subject.transitive_dependencies("module-one", {"module-one" => Set.new}).should == ["module-one"].to_set
    end

    it "should work for the recursive case" do
      dependency_map = {
        "module-one" => ["a", "b", "c"].to_set,
        "a" => ["d"].to_set,
        "b" => ["d", "e"].to_set,
        "c" => Set.new,
        "d" => ["e"].to_set,
        "e" => Set.new,
        "f" => Set.new
      }

      transitive_map = subject.transitive_dependencies("module-one", dependency_map)
      transitive_map.should == ["module-one", "a", "b", "c", "d", "e"].to_set
    end
  end

  describe "#file_to_module" do
    before do
      File.stub(:exists?).and_return(false)
    end

    it "should return the module for a src main path" do
      File.stub(:exists?).with("beemo/pom.xml").and_return(true)
      subject.file_to_module("beemo/src/main/java/com/squareup/beemo/BeemoApp.java").should == "beemo"
    end

    it "should return the module in a subdirectory" do
      File.stub(:exists?).with("gateways/cafis/pom.xml").and_return(true)
      subject.file_to_module("gateways/cafis/src/main/java/com/squareup/gateways/cafis/data/DataField_9_6_1.java").should == "gateways/cafis"
    end

    it "should return the module for a src test path even if there is pom in the parent directory" do
      File.stub(:exists?).with("integration/hibernate/pom.xml").and_return(true)
      File.stub(:exists?).with("integration/hibernate/tests/pom.xml").and_return(true)
      subject.file_to_module("integration/hibernate/tests/src/test/java/com/squareup/integration/hibernate/ConfigurationExtTest.java").should == "integration/hibernate/tests"
    end

    it "should return a module for a pom change" do
      File.stub(:exists?).with("common/pom.xml").and_return(true)
      subject.file_to_module("common/pom.xml").should == "common"
    end

    it "should work for a toplevel change" do
      subject.file_to_module("pom.xml").should be_nil
      subject.file_to_module("Gemfile.lock").should be_nil
      subject.file_to_module("non_maven_dependencies/README").should be_nil
    end

    it "should return nil for changes in parents directory" do
      File.stub(:exists?).with("parents/base/pom.xml").and_return(true)
      subject.file_to_module("parents/base/pom.xml").should be_nil
    end
  end
end
