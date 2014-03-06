require 'spec_helper'

describe PassRateHelper do
  before do
    @builds = []
  end

  def create_some_builds_with_build_attempts(count)
    count.times do
      ba = FactoryGirl.create(:build_attempt, :state => :passed)
      ba.build_instance.update_state_from_parts!
      @builds << ba.build_instance
    end
  end

  describe 'error_free_pass_rate' do

    subject { helper.error_free_pass_rate(@builds) }

    context "when all attempts passed" do
      before { create_some_builds_with_build_attempts(3) }
      it { should == '100%' }
    end

    context "when some parts failed before passing" do
      before do
        create_some_builds_with_build_attempts(3)
        FactoryGirl.create(:build_attempt, :state => :failed, :build_part => @builds.first.build_parts.first)
      end
      it { should == '67%' }
    end

    context "when not all parts ever passed" do
      before do
        create_some_builds_with_build_attempts(2)
        @builds.first.update_attributes! :state => :failed
      end
      it { should == '50%' }
    end
  end

  describe 'eventual_pass_rate' do

    subject { helper.eventual_pass_rate(@builds) }

    context "when all attempts passed" do
      before { create_some_builds_with_build_attempts(2) }
      it { should == '100%' }
    end

    context "when some parts failed before passing" do
      before do
        create_some_builds_with_build_attempts(1)

        failed_first = FactoryGirl.create(:build_attempt, :state => :failed)
        FactoryGirl.create(:build_attempt, :state => :passed, :build_part => failed_first.build_part)
        failed_first.build_instance.update_state_from_parts!
        @builds << failed_first.build_instance
      end
      it { should == '100%' }
    end

    context "when not all parts ever passed" do
      before do
        never_passed = FactoryGirl.create(:build_attempt, :state => :failed)
        FactoryGirl.create(:build_attempt, :state => :failed, :build_part => never_passed.build_part)
        never_passed.build_instance.update_state_from_parts!
        @builds << never_passed.build_instance

        create_some_builds_with_build_attempts(1)
      end
      it { should == '50%' }
    end
  end

  describe 'pass_rate_text' do
    subject { helper.pass_rate_text(number) }

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
