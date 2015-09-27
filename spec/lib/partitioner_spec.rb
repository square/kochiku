require 'spec_helper'
require 'partitioner'

describe Partitioner do
  let(:build) { FactoryGirl.create(:build) }

  before do
    allow(GitRepo).to receive(:load_kochiku_yml).and_return(kochiku_yml)
    allow(GitRepo).to receive(:inside_repo).and_yield
    allow(GitRepo).to receive(:inside_copy).and_yield
  end

  describe "#for_build" do
    subject { Partitioner.for_build(build) }

    context "when there is no kochiku.yml" do
      let(:kochiku_yml) { nil }

      it "should return a single partiion" do
        partitions = subject.partitions
        expect(partitions.size).to eq(1)
        expect(partitions.first["type"]).to eq("test")
        expect(partitions.first["files"]).not_to be_empty
      end
    end

    context "when there is a kochiku.yml" do
      context "when no partitioner is specified" do
        let(:kochiku_yml) do
          {
            "ruby" => ["ree-1.8.7-2011.12"],
            "targets" => [
              {
                'type' => 'rspec',
                'glob' => 'spec/**/*_spec.rb',
                'workers' => 3,
              }
            ]
          }
        end

        it "parses options from kochiku yml" do
          partitions = subject.partitions
          expect(partitions.first["options"]["ruby"]).to eq("ree-1.8.7-2011.12")
          expect(partitions.first["type"]).to eq("rspec")
          expect(partitions.first["files"]).not_to be_empty
          expect(partitions.first["queue"]).to eq("developer")
          expect(partitions.first["retry_count"]).to eq(0)
        end
      end

      context "when using the maven partitioner" do
        let(:kochiku_yml) { {'partitioner' => 'maven'} }

        it "should call the maven partitioner" do
          expect(subject).to be_a(Partitioner::Maven)
        end
      end
    end
  end
end
