require 'spec_helper'
require 'partitioner/go'

describe Partitioner::Go do
  let(:repository) { FactoryGirl.create(:repository) }
  let(:branch) { FactoryGirl.create(:master_branch, repository: repository, name: "master") }
  let(:build) { FactoryGirl.create(:build, branch_record: branch) }
  let(:kochiku_yml) { nil }

  subject { Partitioner::Go.new(build, kochiku_yml) }

  before do
    allow(GitRepo).to receive(:inside_copy).and_yield 'some_dir'
  end

  context "with actual files" do

    let(:go_list_output) {
      <<-OUTPUT
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
        dep_map = subject.module_dependency_map

        expect(dep_map["liba"]).to eq(%w(liba libc libe_test).to_set)
        expect(dep_map["libb"]).to eq(%w(libb libc libe).to_set)
        expect(dep_map["libc"]).to eq(["libc", "libd"].to_set)
        expect(dep_map["libd"]).to eq(["libd"].to_set)
        expect(dep_map["libe"]).to eq(["libe"].to_set)
      end
    end

    describe "#depends_on_map" do
      it "it should get the dependencies" do
        dep_map = subject.depends_on_map

        expect(dep_map["liba"]).to eq(%w(liba libc libd libe_test).to_set)
        expect(dep_map["libb"]).to eq(%w(libb libc libe).to_set)
        expect(dep_map["libc"]).to eq(["libc", "libd"].to_set)
        expect(dep_map["libd"]).to eq(["libd"].to_set)
        expect(dep_map["libe"]).to eq(["libe"].to_set)
      end
    end
  end
end
