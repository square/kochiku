require 'spec_helper'
require 'partitioner/maven'

describe Partitioner::Maven do
  let(:repository) { FactoryGirl.create(:repository) }
  let(:project) { FactoryGirl.create(:project, :repository => repository, :name => repository.name) }
  let(:build) { FactoryGirl.create(:build, :project => project, :branch => "master") }
  let(:kochiku_yml) { nil }

  subject { Partitioner::Maven.new(build, kochiku_yml) }

  before do
    allow(GitRepo).to receive(:inside_copy).and_yield
  end

  describe "#group_modules" do
    it "should group modules based on the top level directory" do
      modules = ["a", "b", "b/1", "b/2", "b/1/2", "c/1"]
      partitions = subject.group_modules(modules)
      expect(partitions.size).to eq(3)
      expect(partitions).to include(a_hash_including({ 'files' => ['a'] }))
      expect(partitions).to include(a_hash_including({ 'files' => ['b', 'b/1', 'b/1/2', 'b/2'] }))
      expect(partitions).to include(a_hash_including({ 'files' => ['c/1'] }))
    end

    context "with expand_directories" do
      let(:kochiku_yml) {
        {
          'maven_settings' => {
            'expand_directories' => ['b'],
          }
        }
      }
      it "should break down modules when included in expand_directories" do
        modules = ["a", "b", "b/elephant", "b/elephant/elephant-protos", "b/mint",]
        partitions = subject.group_modules(modules)
        expect(partitions.size).to eq(4)
        expect(partitions).to include(a_hash_including({ 'files' => ['a'] }))
        expect(partitions).to include(a_hash_including({ 'files' => ['b'] }))
        expect(partitions).to include(a_hash_including({ 'files' => ['b/elephant', 'b/elephant/elephant-protos'] }))
        expect(partitions).to include(a_hash_including({ 'files' => ['b/mint'] }))
      end
    end
  end

  describe "#partitions" do
    context "on master as the main build for the project" do
      before do
        expect(build.project).to be_main
        allow(subject).to receive(:sort_modules) { |mvn_modules| mvn_modules }
      end

      context "for a given set of file changes" do
        before do
          allow(GitBlame).to receive(:files_changed_since_last_build).with(build, sync: anything)
            .and_return([{:file => "module-one/src/main/java/com/lobsters/foo.java", :emails => []},
                         {:file => "module-two/src/main/java/com/lobsters/bar.java", :emails => []}])
          allow(File).to receive(:exists?).and_return(false)
          allow(File).to receive(:exists?).with("module-one/pom.xml").and_return(true)
          allow(File).to receive(:exists?).with("module-two/pom.xml").and_return(true)

          allow(subject).to receive(:maven_modules).and_return(["module-one", "module-two", "module-two/integration", "module-three", "module-four"])
          allow(subject).to receive(:depends_on_map).and_return({
            "module-one" => ["module-one", "module-three", "module-four"].to_set,
            "module-two" => ["module-two", "module-two/integration", "module-three"].to_set,
          })
          expect(subject).to_not receive(:all_partitions)
        end

        it "should return the set of modules to build" do
          partitions = subject.partitions

          expect(partitions.first['type']).to eq('maven') # This should be true for all partitioner actions
          expect(partitions.first['options']).to_not include('log_file_globs') # Unless log_file_globs is set

          expect(partitions.size).to eq(4)
          expect(partitions).to include(a_hash_including({ 'files' => ['module-one'] }))
          expect(partitions).to include(a_hash_including({ 'files' => ['module-two', 'module-two/integration'] }))
          expect(partitions).to include(a_hash_including({ 'files' => ['module-three'] }))
          expect(partitions).to include(a_hash_including({ 'files' => ['module-four'] }))
        end

        context "multiple workers are specified for a module" do
          let(:kochiku_yml) {
            {
              'maven_settings' => {
                'multiple_workers' => {'module-one' => 3}
              }
            }
          }

          it "should return set of modules to build, with separate entries for each test chunk" do
            partitions = subject.partitions

            expect(partitions.size).to eq(6)
            expect(partitions).to include(a_hash_including({ 'files' => ['module-one'], 'options'=>{'total_workers' => 3, 'worker_chunk' => 1}}))
            expect(partitions).to include(a_hash_including({ 'files' => ['module-one'], 'options'=>{'total_workers' => 3, 'worker_chunk' => 2}}))
            expect(partitions).to include(a_hash_including({ 'files' => ['module-one'], 'options'=>{'total_workers' => 3, 'worker_chunk' => 3}}))
            expect(partitions).to include(a_hash_including({ 'files' => ['module-three'], 'options'=>{}}))
          end
        end

        context "with always_build set" do
          let(:kochiku_yml) {
            {
              'maven_settings' => {
                'always_build' => ['module-b'],
              }
            }
          }

          it "should always include the always_build in the partitions" do
            partitions = subject.partitions
            expect(partitions.size).to eq(5)
            expect(partitions).to include(a_hash_including({ 'files' => ['module-b'] }))
          end
        end

        context 'with log_file_globs' do
          let(:kochiku_yml) {{ 'log_file_globs' => log_files }}

          context 'that uses a single string' do
            let(:log_files) { 'mylog.log' }

            it 'puts an array into the options' do
              partitions = subject.partitions
              expect(partitions.first['options']['log_file_globs']).to eq(['mylog.log'])
            end
          end

          context 'that uses an array' do
            let(:log_files) { ['mylog.log', 'another.log'] }

            it 'puts the array into the options' do
              partitions = subject.partitions
              expect(partitions.first['options']['log_file_globs']).to eq(['mylog.log', 'another.log'])
            end
          end
        end

        context "with ignore_paths set" do
          let(:kochiku_yml) {
            {
              'maven_settings' => {
                'ignore_paths' => ['module-two'],
              }
            }
          }

          it "should not return partitions for an ignored directory" do
            partitions = subject.partitions
            expect(partitions.size).to eq(3)
            expect(partitions).to include(a_hash_including({ 'files' => ['module-one'] }))
            expect(partitions).to include(a_hash_including({ 'files' => ['module-three'] }))
            expect(partitions).to include(a_hash_including({ 'files' => ['module-four'] }))
          end
        end
      end

      context "with a previous build" do
        let(:build2) { FactoryGirl.create(:build, :project => project, :branch => "master") }
        subject { Partitioner::Maven.new(build2, kochiku_yml) }

        it "should add all the non-successful parts from the previous build" do
          build_part = FactoryGirl.create(:build_part, :build_instance => build, :paths => ["module-one"])
          expect(build.build_parts.first).to be_unsuccessful

          partitions = subject.partitions
          expect(partitions.size).to eq(1)
          expect(partitions).to include(a_hash_including(
            { "files" => build_part.paths, "queue" => build_part.queue.to_s }))
        end

        it "should not add all successful parts from the previous build" do
          build_part = FactoryGirl.create(:build_part, :build_instance => build, :paths => ["module-one"])
          FactoryGirl.create(:build_attempt, :build_part => build_part, :state => :passed)
          expect(build.build_parts.first).to be_successful

          partitions = subject.partitions
          expect(partitions.size).to eq(0)
        end
      end

      context "with build_everything set" do
        let(:kochiku_yml) {
          {
              'maven_settings' => {
                  'build_everything' => ['build-all'],
              }
          }
        }

        it "should build everything if one of the changed file starts with a path in build_everything" do
          allow(GitBlame).to receive(:files_changed_since_last_build).with(build, sync: anything)
            .and_return([{:file => "build-all/src/main/java/com/lobsters/foo.java", :emails => []}])
          allow(File).to receive(:exists?).and_return(false)
          allow(subject).to receive(:pom_for).and_return ""

          allow(subject).to receive(:maven_modules).and_return(["module-one", "build-all"])
          allow(subject).to receive(:depends_on_map).and_return({
            "module-one" => ["module-one", "build-all"].to_set,
            "build-all" => ["build-all"].to_set,
          })

          expect(subject).to receive(:all_partitions).and_return([{"type" => "maven", "files" => "ALL"}])

          partitions = subject.partitions
          expect(partitions.size).to eq(1)
          expect(partitions.first).to match('type' => 'maven', 'files' => 'ALL', 'options' => {})
        end
      end

      it "should build everything if one of the files does not map to a module" do
        allow(GitBlame).to receive(:files_changed_since_last_build).with(build, sync: anything)
          .and_return([{:file => "toplevel/foo.xml", :emails => []}])

        allow(subject).to receive(:depends_on_map).and_return({
          "module-one" => ["module-one", "module-three", "module-four"].to_set,
          "module-two" => ["module-two", "module-three"].to_set
        })

        expect(subject).to receive(:all_partitions).and_return([{"type" => "maven", "files" => "ALL"}])

        partitions = subject.partitions
        expect(partitions.size).to eq(1)
        expect(partitions.first).to match('type' => 'maven', 'files' => 'ALL', 'options' => {})
      end

      it "should not fail if a file is referenced in a top level module that is not in the top level pom" do
        allow(GitBlame).to receive(:files_changed_since_last_build).with(build, sync: anything)
          .and_return([{:file => "new-module/src/main/java/com/lobsters/foo.java", :emails => []}])

        allow(File).to receive(:exists?).and_return(false)
        allow(File).to receive(:exists?).with("new-module/pom.xml").and_return(true)

        allow(subject).to receive(:maven_modules).and_return(["module-one", "module-two"])
        allow(subject).to receive(:depends_on_map).and_return({
          "module-one" => ["module-one", "module-three", "module-four"].to_set,
          "module-two" => ["module-two", "module-three"].to_set
        })
        expect(subject).to_not receive(:all_partitions)

        partitions = subject.partitions
        expect(partitions.size).to eq(0)
      end

      context "with options" do
        let(:kochiku_yml) {{ 'log_file_globs' => 'mylog.log', 'retry_count' => 5 }}

        it "should include options in the event of a partial build" do
          allow(GitBlame).to receive(:files_changed_since_last_build).with(build, sync: anything)
            .and_return([{:file => "toplevel/foo.xml", :emails => []}])

          expect(subject).to receive(:all_partitions).and_return([{"type" => "maven", "files" => "ALL"}])

          partitions = subject.partitions
          expect(partitions.size).to be > 0
          expect(partitions.first).to match a_hash_including('options' =>
              {'log_file_globs' => ['mylog.log'], 'retry_count' => 5})
        end
      end
    end

    context "on a branch" do
      let(:build) { FactoryGirl.create(:build, :branch => "branch-of-master") }

      before do
        expect(build.project).to_not be_main
      end

      context "with a previous build" do
        let(:build2) { FactoryGirl.create(:build, :project => project, :branch => "master") }
        subject { Partitioner::Maven.new(build2, kochiku_yml) }

        it "should NOT add all the non-successful parts from the previous build" do
          build_part = FactoryGirl.create(:build_part, :build_instance => build, :paths => ["module-one"])
          expect(build.build_parts.first).to be_unsuccessful
          allow(subject).to receive(:sort_modules) { |mvn_modules| mvn_modules }

          partitions = subject.partitions
          expect(partitions.size).to eq(0)
        end
      end
    end
  end

  describe "#emails_for_commits_causing_failures" do
    it "should return nothing if there are no failed parts" do
      expect(build.build_parts.failed_or_errored).to be_empty
      emails = subject.emails_for_commits_causing_failures
      expect(emails).to be_empty
    end

    context "with a module that failed to build" do
      before do
        build_part = FactoryGirl.create(:build_part, :paths => ["failed-module"], :build_instance => build)
        FactoryGirl.create(:build_attempt, :state => :failed, :build_part => build_part)
        expect(build.build_parts.failed_or_errored).to eq([build_part])

        allow(GitRepo).to receive(:inside_copy).and_yield
        expect(subject).to_not receive(:all_partitions)
      end

      it "should return the emails for the modules that are failing" do
        allow(GitBlame).to receive(:files_changed_since_last_green).with(build, fetch_emails: true)
                           .and_return([{:file => "module-one/src/main/java/com/lobsters/Foo.java", :emails => ["userone@example.com"]},
                                        {:file => "module-two/src/main/java/com/lobsters/Bar.java", :emails => ["usertwo@example.com"]},
                                        {:file => "failed-module/src/main/java/com/lobsters/Baz.java", :emails => ["userfour@example.com"]},
                                        {:file => "failed-module/src/main/java/com/lobsters/Bing.java", :emails => ["userfour@example.com"]}])
        allow(File).to receive(:exists?).and_return(false)
        allow(File).to receive(:exists?).with("module-one/pom.xml").and_return(true)
        allow(File).to receive(:exists?).with("module-two/pom.xml").and_return(true)
        allow(File).to receive(:exists?).with("failed-module/pom.xml").and_return(true)

        allow(subject).to receive(:depends_on_map).and_return({
                                                                  "module-one" => ["module-one", "module-three", "failed-module"].to_set,
                                                                  "module-two" => ["module-two", "module-three"].to_set,
                                                                  "failed-module" => ["failed-module"].to_set
                                                              })

        email_and_files = subject.emails_for_commits_causing_failures
        expect(email_and_files.size).to eq(2)
        expect(email_and_files["userone@example.com"]).to eq(["module-one/src/main/java/com/lobsters/Foo.java"])
        expect(email_and_files["userfour@example.com"].size).to eq(2)
        expect(email_and_files["userfour@example.com"]).to include("failed-module/src/main/java/com/lobsters/Baz.java")
        expect(email_and_files["userfour@example.com"]).to include("failed-module/src/main/java/com/lobsters/Bing.java")
      end

      context "with ignore_paths set" do
        let(:kochiku_yml) {
          {
              'maven_settings' => {
                  'ignore_paths' => ['ignored-module'],
              }
          }
        }

        it "should not return emails if changes are on an ignored path and not in the dependency map" do
          allow(GitBlame).to receive(:files_changed_since_last_green).with(build, fetch_emails: true)
                             .and_return([{:file => "ignored-module/src/main/java/com/lobsters/Foo.java", :emails => ["userone@example.com"]},
                                          {:file => "failed-module/src/main/java/com/lobsters/Bing.java", :emails => ["userfour@example.com"]}])
          allow(File).to receive(:exists?).and_return(false)
          allow(File).to receive(:exists?).with("ignored-module/pom.xml").and_return(true)
          allow(File).to receive(:exists?).with("failed-module/pom.xml").and_return(true)

          allow(subject).to receive(:depends_on_map).and_return({
                                                                    "ignored-module" => ["ignored-module"].to_set,
                                                                    "failed-module" => ["failed-module"].to_set
                                                                })

          email_and_files = subject.emails_for_commits_causing_failures
          expect(email_and_files.size).to eq(1)
          expect(email_and_files["userfour@example.com"]).to eq(["failed-module/src/main/java/com/lobsters/Bing.java"])
        end

        it "should return emails if changes are on an ignored path but are in the dependency map" do
          allow(GitBlame).to receive(:files_changed_since_last_green).with(build, fetch_emails: true)
                             .and_return([{:file => "ignored-module/src/main/java/com/lobsters/Foo.java", :emails => ["userone@example.com"]},
                                          {:file => "failed-module/src/main/java/com/lobsters/Bing.java", :emails => ["userfour@example.com"]}])
          allow(File).to receive(:exists?).and_return(false)
          allow(File).to receive(:exists?).with("ignored-module/pom.xml").and_return(true)
          allow(File).to receive(:exists?).with("failed-module/pom.xml").and_return(true)

          allow(subject).to receive(:depends_on_map).and_return({
                                                                    "ignored-module" => ["ignored-module", "failed-module"].to_set,
                                                                    "failed-module" => ["failed-module"].to_set
                                                                })

          email_and_files = subject.emails_for_commits_causing_failures
          expect(email_and_files.size).to eq(2)
          expect(email_and_files["userone@example.com"]).to eq(["ignored-module/src/main/java/com/lobsters/Foo.java"])
          expect(email_and_files["userfour@example.com"]).to eq(["failed-module/src/main/java/com/lobsters/Bing.java"])
        end
      end

      context "with build_everything set" do
        let(:kochiku_yml) {
          {
              'maven_settings' => {
                  'build_everything' => ['build-all'],
              }
          }
        }

        it "should return email for change to build_everything even if build_everything module does not depend on changed file" do
          allow(GitBlame).to receive(:files_changed_since_last_green).with(build, fetch_emails: true)
                             .and_return([{:file => "build-all/src/main/java/com/lobsters/Foo.java", :emails => ["userone@example.com"]},
                                          {:file => "module-four/src/main/java/com/lobsters/Bar.java", :emails => ["userfour@example.com"]}])
          allow(File).to receive(:exists?).and_return(false)
          allow(File).to receive(:exists?).with("build-all/pom.xml").and_return(true)
          allow(File).to receive(:exists?).with("failed-module/pom.xml").and_return(true)

          allow(subject).to receive(:depends_on_map).and_return({
                                                                    "build-all" => ["build-all"].to_set,
                                                                    "module-four" => ["module-four"].to_set
                                                                })

          email_and_files = subject.emails_for_commits_causing_failures
          expect(email_and_files.size).to eq(2)
          expect(email_and_files["userone@example.com"]).to eq(["build-all/src/main/java/com/lobsters/Foo.java"])
          expect(email_and_files["userfour@example.com"]).to eq(["module-four/src/main/java/com/lobsters/Bar.java"])
        end
      end
    end
  end

  describe "#sort_modules" do
    before do
      allow(subject).to receive(:module_dependency_map).and_return({
                        "module-one" => ["module-two"].to_set,
                        "module-two" => ["module-three"].to_set,
                        "module-three" => ["module-four"].to_set,
                        "module-four" => Set.new,
                        "module-five" => Set.new,
                      })
    end

    it "should sort the modules based on a topological sort of the dependency map" do
      sorted_modules = subject.sort_modules(["module-one", "module-three", "module-four", "module-two"])
      expect(sorted_modules).to eq(["module-four", "module-three", "module-two", "module-one"])
    end

    it "should sort partial module lists that depend on each other" do
      sorted_modules = subject.sort_modules(["module-two", "module-three"])
      expect(sorted_modules).to eq(["module-three", "module-two"])
    end

    it "should sort partial module lists of one" do
      expect(subject.sort_modules(["module-two"])).to eq(["module-two"])
    end

    it "should sort empty module lists" do
      expect(subject.sort_modules([])).to eq([])
    end
  end

  describe "#depends_on_map" do
    it "should convert a dependency map to a depends on map" do
      allow(subject).to receive(:transitive_dependency_map).and_return({
                                                           "module-one" => ["a", "b"].to_set,
                                                           "module-two" => ["b", "c", "module-one"].to_set,
                                                           "module-three" => Set.new
                                                         })

      depends_on_map = subject.depends_on_map

      expect(depends_on_map["module-one"]).to eq(["module-one", "module-two"].to_set)
      expect(depends_on_map["module-two"]).to eq(["module-two"].to_set)
      expect(depends_on_map["module-three"]).to eq(["module-three"].to_set)
      expect(depends_on_map["a"]).to eq(["a", "module-one"].to_set)
      expect(depends_on_map["b"]).to eq(["b", "module-one", "module-two"].to_set)
      expect(depends_on_map["c"]).to eq(["c", "module-two"].to_set)
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

  <groupId>com.lobsters</groupId>
  <artifactId>module-core</artifactId>

  <dependencies>
    <dependency>
      <groupId>com.lobsters</groupId>
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

  <groupId>com.lobsters</groupId>
  <artifactId>module-extras</artifactId>

  <dependencies>
    <dependency>
      <groupId>com.lobsters</groupId>
      <artifactId>module-three</artifactId>
    </dependency>
  </dependencies>
</project>
    POM
    }

    let(:module_three_pom) { <<-POM
<project>
  <groupId>com.lobsters</groupId>
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

    let(:module_four_pom) { <<-POM
<project>
  <properties>
    <deployableBranch>super-branch</deployableBranch>
  </properties>

  <groupId>com.lobsters</groupId>
  <artifactId>module-four</artifactId>

  <dependencies>
    <dependency>
      <groupId>com.lobsters</groupId>
      <artifactId>super-module</artifactId>
    </dependency>
  </dependencies>
</project>
    POM
    }

    before do
      allow(File).to receive(:read).with(Partitioner::Maven::POM_XML).and_return(top_level_pom)
      allow(File).to receive(:read).with("module-one/pom.xml").and_return(module_one_pom)
      allow(File).to receive(:read).with("module-two/pom.xml").and_return(module_two_pom)
      allow(File).to receive(:read).with("module-three/pom.xml").and_return(module_three_pom)
    end

    describe "#module_dependency_map" do
      it "it should get the dependencies from a pom" do
        dependency_map = subject.module_dependency_map

        expect(dependency_map["module-one"]).to eq(["module-two"].to_set)
        expect(dependency_map["module-two"]).to eq(["module-three"].to_set)
        expect(dependency_map["module-three"]).to eq(Set.new)
      end

      context "with a dependency missing a groupId" do
        let(:module_three_pom) { <<-POM
<project>
  <groupId>com.lobsters</groupId>
  <artifactId>module-three</artifactId>

  <dependencies>
    <dependency>
      <artifactId>junit</artifactId>
    </dependency>
  </dependencies>
</project>
        POM
        }

        it "it should return a useful error message" do
          expect { subject.module_dependency_map }.to raise_error("dependency in module-three/pom.xml is missing an artifactId or groupId")
        end
      end
    end

    describe "#transitive_dependency_map" do
      it "it should get the transitive dependencies from a pom" do
        dependency_map = subject.transitive_dependency_map

        expect(dependency_map["module-one"]).to eq(["module-one", "module-two", "module-three"].to_set)
        expect(dependency_map["module-two"]).to eq(["module-two", "module-three"].to_set)
        expect(dependency_map["module-three"]).to eq(["module-three"].to_set)
      end
    end
  end

  describe "#transitive_dependencies" do
    it "should return the module in a set as a base case" do
      expect(subject.transitive_dependencies("module-one", {"module-one" => Set.new})).to eq(["module-one"].to_set)
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
      expect(transitive_map).to eq(["module-one", "a", "b", "c", "d", "e"].to_set)
    end
  end

  describe "#file_to_module" do
    before do
      allow(File).to receive(:exists?).and_return(false)
    end

    it "should return the module for a src main path" do
      allow(File).to receive(:exists?).with("oyster/pom.xml").and_return(true)
      expect(subject.file_to_module("oyster/src/main/java/com/lobsters/oyster/OysterApp.java")).to eq("oyster")
    end

    it "should return the module in a subdirectory" do
      allow(File).to receive(:exists?).with("gateways/cafis/pom.xml").and_return(true)
      expect(subject.file_to_module("gateways/cafis/src/main/java/com/lobsters/gateways/cafis/data/DataField_9_6_1.java"))
        .to eq("gateways/cafis")
    end

    it "should return the module for a src test path even if there is pom in the parent directory" do
      allow(File).to receive(:exists?).with("integration/hibernate/pom.xml").and_return(true)
      allow(File).to receive(:exists?).with("integration/hibernate/tests/pom.xml").and_return(true)
      expect(subject.file_to_module("integration/hibernate/tests/src/test/java/com/lobsters/integration/hibernate/ConfigurationExtTest.java"))
        .to eq("integration/hibernate/tests")
    end

    it "should return a module for a pom change" do
      allow(File).to receive(:exists?).with("common/pom.xml").and_return(true)
      expect(subject.file_to_module("common/pom.xml")).to eq("common")
    end

    it "should return nil for a toplevel change" do
      expect(subject.file_to_module("pom.xml")).to be_nil
      expect(subject.file_to_module("Gemfile.lock")).to be_nil
      expect(subject.file_to_module("non_maven_dependencies/README")).to be_nil
    end
  end
end
