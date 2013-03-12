require 'spec_helper'

describe MavenPartitioner do
  subject { MavenPartitioner.new }

  describe "#incremental_partitions" do
    let(:build) { FactoryGirl.create(:build) }

    it "should return the set of modules to build for a given set of file changes" do
      GitBlame.stub(:files_changed_since_last_green).with(build).and_return(["module-one/src/main/java/com/squareup/foo.java",
                                                                             "module-two/src/main/java/com/squareup/bar.java"])

      subject.stub(:depends_on_map).and_return({
          "module-one" => ["module-three", "module-four"].to_set,
          "module-two" => ["module-three"].to_set
      })

      partitions = subject.incremental_partitions(build)
      partitions.size.should == 2
      if partitions[0]["files"][0] == "module-three"
        partitions[1]["files"][0].should == "module-four"
      else
        partitions[0]["files"][0].should == "module-four"
        partitions[1]["files"][0].should == "module-three"
      end
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

      depends_on_map["module_one"].should == ["module_two"].to_set
      depends_on_map["module_two"].should be_empty
      depends_on_map["module_three"].should be_empty
      depends_on_map["a"].should == ["module_one"].to_set
      depends_on_map["b"].should include("module_one")
      depends_on_map["b"].should include("module_two")
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
    it "should return the module for a src main path" do
      subject.file_to_module("beemo/src/main/java/com/squareup/beemo/BeemoApp.java").should == "beemo"
      subject.file_to_module("gateways/cafis/src/main/java/com/squareup/gateways/cafis/data/DataField_9_6_1.java").should == "gateways/cafis"
    end

    it "should return the module for a resource path" do
      subject.file_to_module("beemo/src/main/resources/beemo-common.yaml").should == "beemo"
    end

    it "should return the module for a src test path" do
      subject.file_to_module("integration/hibernate/tests/src/test/java/com/squareup/integration/hibernate/ConfigurationExtTest.java").should == "integration/hibernate/tests"
    end
  end
end