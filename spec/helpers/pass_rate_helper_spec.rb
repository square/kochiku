require 'spec_helper'

describe PassRateHelper do

  module Helper
    extend PassRateHelper
  end

  let!(:builds) {
    3.times.map { FactoryGirl.create(:build, :state => :succeeded) }
  }
  let!(:build_parts) {
    builds.map {|build|
      build_part = FactoryGirl.create(:build_part, :paths => ["a", "b"],
                                      :kind => "spec",
                                      :build_instance => build,
                                      :queue => 'ci')
      FactoryGirl.create(:build_attempt, :state => :passed, :build_part => build_part)
      build_part
    }
  }

  describe 'error_free_pass_rate' do

    subject { Helper.error_free_pass_rate(builds) }

    context "when all attempts passed" do
      it { should == '100%' }
    end

    context "when some parts failed before passing" do
      before do
        FactoryGirl.create(:build_attempt, :state => :failed, :build_part => build_parts.first)
      end
      it { should == '67%' }
    end

    context "when not all parts ever passed" do
      before do
        builds.first.update_attributes! :state => :failed
      end
      it { should == '67%' }
    end
  end

  describe 'eventual_pass_rate' do

    subject { Helper.eventual_pass_rate(builds) }

    context "when all attempts passed" do
      it { should == '100%' }
    end

    context "when some parts failed before passing" do
      before do
        FactoryGirl.create(:build_attempt, :state => :failed, :build_part => build_parts.first)
      end
      it { should == '100%' }
    end

    context "when not all parts ever passed" do
      before do
        build_parts.first.build_attempts.delete_all # remove the good one
        FactoryGirl.create(:build_attempt, :state => :failed, :build_part => build_parts.first)
        builds.first.update_attributes! :state => :failed
      end
      it { should == '67%' }
    end
  end

  describe 'pass_rate_text' do
    subject { Helper.pass_rate_text(number) }

    context "for a perfect score" do
      let(:number) { 1.000000 }
      it { should == '100%' }
    end

    context "for a zero score" do
      let(:number) { 0 }
      it { should == '0%' }
    end

    context "for a middlin' score" do
      let(:number) { 0.421643 }
      it { should == '42%' }
    end
  end
end
