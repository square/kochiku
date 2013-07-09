require 'spec_helper'

describe Partitioner do
  let(:build) { FactoryGirl.create(:build) }
  let(:partitioner) { Partitioner.new }

  before do
    YAML.stub(:load_file).with(Partitioner::BUILD_YML).and_return(build_yml)
    YAML.stub(:load_file).with(Partitioner::KOCHIKU_YML).and_return(kochiku_yml)
    File.stub(:exist?).with(MavenPartitioner::POM_XML).and_return(pom_xml_exists)
    File.stub(:exist?).with(Partitioner::KOCHIKU_YML).and_return(kochiku_yml_exists)
    File.stub(:exist?).with(Partitioner::BUILD_YML).and_return(build_yml_exists)
  end

  let(:build_yml) {{
    'host1' => {
      'type'  => 'rspec',
      'files' => '<FILES>'
    },
    'bad config' => {}
  }}

  let(:kochiku_yml) {[
    { 'type' => 'rspec', 'glob' => 'spec/**/*_spec.rb', 'workers' => 3, 'balance' => balance, 'manifest' => manifest }
  ]}

  let(:kochiku_yml_exists) { false }
  let(:pom_xml_exists) { false }
  let(:build_yml_exists) { false }
  let(:balance) { 'alphabetically' }
  let(:manifest) { nil }

  context "with a ruby-based kochiku.yml" do
    let(:kochiku_yml_exists) { true }
    let(:kochiku_yml) do
      {
        "ruby" => ["ree-1.8.7-2011.12"],
        "language" => "ruby",
        "targets" => [
          { 'type' => 'rspec', 'glob' => 'spec/**/*_spec.rb', 'workers' => 3, 'balance' => balance, 'manifest' => manifest }
        ]
      }
    end

    it "parses options from kochiku yml" do
      partitions = partitioner.partitions(build)
      partitions.first["options"]["language"].should == "ruby"
      partitions.first["options"]["ruby"].should == "ree-1.8.7-2011.12"
      partitions.first["type"].should == "rspec"
      partitions.first["files"].should_not be_empty
    end

    describe "using the deprecated rvm option" do
      let(:kochiku_yml) do
        {
          "ruby" => ["ree-1.8.7-2011.12"],
          "language" => "ruby",
          "targets" => [
            { 'type' => 'rspec', 'glob' => 'spec/**/*_spec.rb', 'workers' => 3, 'balance' => balance, 'manifest' => manifest }
          ]
        }
      end

      it "parses the rvm option as ruby" do
        partitioner.partitions(build).first["options"]["ruby"].should == "ree-1.8.7-2011.12"
      end
    end
  end

  context "when there is no config yml" do
    let(:kochiku_yml_exists) { false }
    let(:build_yml_exists) { false }

    it "should return a single partiion" do
      partitions = partitioner.partitions(build)
      partitions.size.should == 1
      partitions.first["type"].should == "spec"
      partitions.first["files"].should_not be_empty
    end
  end

  describe '#partitions' do
    subject { partitioner.partitions(build) }

    context 'when there is not a kochiku.yml' do
      let(:kochiku_yml_exists) { false }
      let(:build_yml_exists) { true }
      it { should == [{'type' => 'rspec', 'files' => '<FILES>'}] }
    end

    context 'when there is a kochiku.yml' do
      let(:kochiku_yml_exists) { true }

      before { Dir.stub(:[]).and_return(matches) }

      context 'when there are no files matching the glob' do
        let(:matches) { [] }
        it { should == [] }
      end

      context 'when there is one file matching the glob' do
        let(:matches) { %w(a) }
        it { should == [{ 'type' => 'rspec', 'files' => %w(a) }] }
      end

      context 'when there are many files matching the glob' do
        let(:matches) { %w(a b c d) }
        it { should == [
          { 'type' => 'rspec', 'files' => %w(a b) },
          { 'type' => 'rspec', 'files' => %w(c) },
          { 'type' => 'rspec', 'files' => %w(d) },
        ] }

        context 'and balance is round_robin' do
          let(:balance) { 'round_robin' }
          it { should == [
            { 'type' => 'rspec', 'files' => %w(a d) },
            { 'type' => 'rspec', 'files' => %w(b) },
            { 'type' => 'rspec', 'files' => %w(c) },
          ] }

          context 'and a manifest file is specified' do
            before { YAML.stub(:load_file).with(manifest).and_return { %w(c b a) } }
            let(:manifest) { 'manifest.yml' }
            let(:matches) { %w(a b c d) }

            it { should == [
              { 'type' => 'rspec', 'files' => %w(c d) },
              { 'type' => 'rspec', 'files' => %w(b) },
              { 'type' => 'rspec', 'files' => %w(a) },
            ]
            }
          end
        end

        context 'and balance is size' do
          let(:balance) { 'size' }

          before do
            File.stub(:size).with('a').and_return(1)
            File.stub(:size).with('b').and_return(1000)
            File.stub(:size).with('c').and_return(100)
            File.stub(:size).with('d').and_return(10)
          end

          it { should == [
            { 'type' => 'rspec', 'files' => %w(b a) },
            { 'type' => 'rspec', 'files' => %w(c) },
            { 'type' => 'rspec', 'files' => %w(d) },
          ] }
        end

        context 'and balance is size_greedy_partitioning' do
          let(:balance) { 'size_greedy_partitioning' }

          before do
            File.stub(:size).with('a').and_return(1)
            File.stub(:size).with('b').and_return(1000)
            File.stub(:size).with('c').and_return(100)
            File.stub(:size).with('d').and_return(10)
          end

          it { should =~ [
            { 'type' => 'rspec', 'files' => %w(b) },
            { 'type' => 'rspec', 'files' => %w(c) },
            { 'type' => 'rspec', 'files' => %w(d a) },
          ] }
        end

        context 'and balance is size_average_partitioning' do
          let(:balance) { 'size_average_partitioning' }

          before do
            File.stub(:size).with('a').and_return(1)
            File.stub(:size).with('b').and_return(1000)
            File.stub(:size).with('c').and_return(100)
            File.stub(:size).with('d').and_return(10)
          end

          it { should == [
            { 'type' => 'rspec', 'files' => %w(a b) },
            { 'type' => 'rspec', 'files' => %w(c) },
            { 'type' => 'rspec', 'files' => %w(d) },
          ] }
        end

        context 'and balance is isolated' do
          let(:balance) { 'isolated' }

          it { should == [
            { 'type' => 'rspec', 'files' => %w(a) },
            { 'type' => 'rspec', 'files' => %w(b) },
            { 'type' => 'rspec', 'files' => %w(c) },
            { 'type' => 'rspec', 'files' => %w(d) },
          ] }
        end
      end
    end

    context 'when there is pom.xml' do
      let(:pom_xml_exists) { true }
      let(:repository) { FactoryGirl.create(:repository, :url => "git@git.squareup.com:square/java.git") }
      let(:project) { FactoryGirl.create(:project, :repository => repository) }
      let(:build) { FactoryGirl.create(:build, :project => project) }

      let(:top_level_pom) { <<-POM
  <project>
    <modules>
      <module>module-one</module>
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

      it "should call the maven partitioner" do
        File.stub(:read).with(MavenPartitioner::POM_XML).and_return(top_level_pom)
        File.stub(:read).with("module-one/pom.xml").and_return(module_one_pom)
        File.stub(:read).with("all-java/pom.xml").and_return("")

        subject.should == [{"type" => "maven", "files" => ["all-java"], "upload_artifacts" => false}]

        build.reload
        build.maven_modules.should == ["module-one"]
        build.deployable_map.should == {"module-one" => "one-branch"}
      end
    end
  end
end
