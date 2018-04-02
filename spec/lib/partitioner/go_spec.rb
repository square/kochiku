require 'spec_helper'
require 'partitioner/go'

describe Partitioner::Go do
  let(:repository) { FactoryBot.create(:repository) }
  let(:branch) { FactoryBot.create(:master_branch, repository: repository, name: "master") }
  let!(:build) { FactoryBot.create(:build, branch_record: branch) }
  let(:kochiku_yml) { nil }

  subject { Partitioner::Go.new(build, kochiku_yml) }

  before do
    allow(GitRepo).to receive(:inside_copy).and_yield 'some_dir'
  end

  context "with actual files" do

    let(:go_list_output) {
      <<~OUTPUT
        {
          "ImportPath": "/vendor/test",
          "Deps": [
            "runtime",
            "runtime/internal/atomic",
            "runtime/internal/sys",
            "unsafe"
          ]
        }
        {
          "ImportPath": "liba",
          "Deps": [
            "runtime",
            "runtime/internal/atomic",
            "runtime/internal/sys",
            "unsafe"
          ]
        }
        {
          "ImportPath": "libb",
          "Deps": [
            "runtime",
            "runtime/internal/atomic",
            "runtime/internal/sys",
            "unsafe"
          ]
        }
        {
          "ImportPath": "libc/test",
          "Deps": [
            "runtime",
            "runtime/internal/atomic",
            "runtime/internal/sys",
            "unsafe"
          ]
        }
        {
          "ImportPath": "libc",
          "Imports": [
            "liba"
          ],
          "Deps": [
            "liba",
            "runtime",
            "runtime/internal/atomic",
            "runtime/internal/sys",
            "unsafe"
          ],
          "TestImports": [
            "libb",
            "testing"
          ]
        }
        {
          "ImportPath": "libd",
          "Imports": [
            "libc"
          ],
          "Deps": [
            "liba",
            "libc",
            "runtime",
            "runtime/internal/atomic",
            "runtime/internal/sys",
            "unsafe"
          ],
          "TestImports": [
            "libc",
            "testing"
          ]
        }
        {
          "ImportPath": "libe",
          "Imports": [
            "libb"
          ],
          "Deps": [
            "libb",
            "runtime",
            "runtime/internal/atomic",
            "runtime/internal/sys",
            "unsafe"
          ],
          "XTestImports": [
            "liba",
            "testing"
          ]
        }
    OUTPUT
    }

    before do
      go_list_double = double('go list')
      allow(go_list_double).to receive(:run).and_return(go_list_output)
      allow(Cocaine::CommandLine).to receive(:new).and_return(go_list_double)
    end

    describe "#package_info_map" do
      it "it should get the package info map" do
        pinfo_map = subject.package_info_map
        expect(pinfo_map["liba"]["ImportPath"]).to eq("liba")
        expect(pinfo_map["liba"]["Deps"]).to eq(["runtime", "runtime/internal/atomic", "runtime/internal/sys", "unsafe"])
        expect(pinfo_map["libb"]["ImportPath"]).to eq("libb")
        expect(pinfo_map["libc"]["Imports"]).to eq(["liba"])
      end
    end

    describe "#module_dependency_map" do
      it "it should get the dependencies" do
        dep_map = subject.package_dependency_map

        expect(dep_map["liba"]).to eq(%w[liba libc libe_test].to_set)
        expect(dep_map["libb"]).to eq(%w[libb libc libe].to_set)
        expect(dep_map["libc"]).to eq(%w[libc libd].to_set)
        expect(dep_map["libd"]).to eq(%w[libd].to_set)
        expect(dep_map["libe"]).to eq(%w[libe].to_set)
      end
    end

    describe "#depends_on_map" do
      it "it should get the dependencies" do
        dep_map = subject.depends_on_map

        expect(dep_map["liba"]).to eq(%w[liba libc libd libe_test].to_set)
        expect(dep_map["libb"]).to eq(%w[libb libc libe].to_set)
        expect(dep_map["libc"]).to eq(%w[libc libd].to_set)
        expect(dep_map["libd"]).to eq(%w[libd].to_set)
        expect(dep_map["libe"]).to eq(%w[libe].to_set)
      end
    end

    describe "#all_packages"  do
      it 'should filter /vendor' do
        expect(subject.all_packages.include?("/vendor/test")).to eq(false)
        expect(subject.all_packages.include?("liba")).to eq(true)
      end
    end

    describe "#add_partitions" do
      it 'should create partitions for all target_types' do
        partitions = subject.add_partitions(subject.all_packages)
        expect(partitions.size).to eq(subject.all_packages_target_types.size + subject.top_level_packages_target_types.size)
      end

    end

    describe "#package_folders_map" do
      it 'should return the packages as folders' do
        folder_map = subject.package_folders_map(subject.all_packages)
        expect(folder_map["liba"]).to eq(%w[./liba/])
        expect(folder_map["libc"]).to eq(%w[./libc/test/ ./libc/])
      end
    end

    describe "#failed_convergence_tests" do
      it 'should return an empty array if there is no previous build' do
        expect(subject.failed_convergence_tests).to eq(%w[])
      end

      it 'should return the failed paths on a previous build' do
        failed_build = FactoryBot.create(:completed_build, branch_record: branch, num_build_parts: 1, state: 'failed')
        allow_any_instance_of(Build).to receive(:previous_build).and_return(failed_build)
        expect(subject.failed_convergence_tests).to eq(%w[/foo/1.test foo/baz/a.test foo/baz/b.test])
      end
    end

    describe "#file_to_packages" do
      it 'should return paths based on a files package dependencies for a .go file' do
        expect(subject.file_to_packages("libb/test.go")).to eq(%w[libb libc libe])
      end

      it 'should return the path of the toplevel package for a non .go file' do
        expect(subject.file_to_packages("libb/readme.md")).to eq(%w[libb])
      end
    end

    describe "#add_with_split" do
      it 'should handle an empty package_list' do
        expect(subject.add_with_split([], "test", 2)).to be_nil
      end
    end
  end
end
