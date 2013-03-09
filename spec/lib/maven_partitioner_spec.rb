require 'spec_helper'

describe MavenPartitioner do
  subject { MavenPartitioner.new }

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