require 'spec_helper'

describe MavenPartitioner do
  subject { MavenPartitioner.new }

  describe "#incremental_partitions" do
    let(:build) { FactoryGirl.create(:build) }

    it "should return the set of modules to build for a given set of file changes" do
      GitBlame.stub(:files_changed_since_last_green).with(build).and_return(["module-one/src/main/java/com/squareup/foo.java",
                                                                             "module-two/src/main/java/com/squareup/bar.java"])
      File.stub(:exists?).and_return(false)
      File.stub(:exists?).with("module-one/pom.xml").and_return(true)
      File.stub(:exists?).with("module-two/pom.xml").and_return(true)

      subject.stub(:depends_on_map).and_return({
          "module-one" => ["module-three", "module-four"].to_set,
          "module-two" => ["module-three"].to_set
      })
      subject.should_not_receive(:partitions)

      partitions = subject.incremental_partitions(build)
      partitions.size.should == 2
      if partitions[0]["files"][0] == "module-three"
        partitions[1]["files"][0].should == "module-four"
      else
        partitions[0]["files"][0].should == "module-four"
        partitions[1]["files"][0].should == "module-three"
      end
    end

    it "should build everything if one of the files does not map to a module" do
      GitBlame.stub(:files_changed_since_last_green).with(build).and_return(["toplevel/foo.xml"])

      subject.stub(:depends_on_map).and_return({
          "module-one" => ["module-three", "module-four"].to_set,
          "module-two" => ["module-three"].to_set
      })

      subject.should_receive(:partitions).and_return([{"type" => "maven", "files" => "ALL"}])

      partitions = subject.incremental_partitions(build)
      partitions.first["files"].should == "ALL"
    end
  end

  describe "#depends_on_map" do
    it "should convert a dependency map to a depends on map" do
      subject.stub(:module_dependency_map).and_return({
          "module_one" => ["a", "b", "c"].to_set,
          "module_two" => ["b", "c", "module_one"].to_set,
          "module_three" => Set.new
      })

      depends_on_map = subject.depends_on_map

      depends_on_map["module_one"].should include("module_one")
      depends_on_map["module_one"].should include("module_two")
      depends_on_map["module_two"].should == ["module_two"].to_set
      depends_on_map["module_three"].should == ["module_three"].to_set
      depends_on_map["a"].should include("a")
      depends_on_map["a"].should include("module_one")
      depends_on_map["b"].should include("b")
      depends_on_map["b"].should include("module_one")
      depends_on_map["b"].should include("module_two")
      depends_on_map["c"].should include("c")
      depends_on_map["c"].should include("module_one")
      depends_on_map["c"].should include("module_two")
    end
  end

  describe "#module_dependency_map" do
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

    it "it should get the transitive dependencies from a pom" do
      File.stub(:read).with(MavenPartitioner::POM_XML).and_return(top_level_pom)
      File.stub(:read).with("module-one/pom.xml").and_return(module_one_pom)
      File.stub(:read).with("module-two/pom.xml").and_return(module_two_pom)
      File.stub(:read).with("module-three/pom.xml").and_return(module_three_pom)

      dependency_map = subject.module_dependency_map

      dependency_map["module-one"].size.should == 2
      dependency_map["module-one"].should include("module-two")
      dependency_map["module-one"].should include("module-three")

      dependency_map["module-two"].should == ["module-three"].to_set
      dependency_map["module-three"].should be_empty
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