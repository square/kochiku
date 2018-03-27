require 'spec_helper'

describe ProjectStatsHelper do
  before do
    @builds = []
  end

  def create_some_builds_with_build_attempts(count)
    count.times do
      ba = FactoryGirl.create(:build_attempt, :state => 'passed')
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
        FactoryGirl.create(:build_attempt, :state => 'failed', :build_part => @builds.first.build_parts.first)
      end
      it { should == '67%' }
    end

    context "when not all parts ever passed" do
      before do
        create_some_builds_with_build_attempts(2)
        @builds.first.update_attributes! :state => 'failed'
      end
      it { should == '50%' }
    end

    context "when the latest build part is running" do
      before do
        create_some_builds_with_build_attempts(3)
        @builds.last.update_attribute(:state, 'running')
      end

      it "should not count running build" do
        expect(subject).to eq('100%')
      end
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

        failed_first = FactoryGirl.create(:build_attempt, :state => 'failed')
        FactoryGirl.create(:build_attempt, :state => 'passed', :build_part => failed_first.build_part)
        failed_first.build_instance.update_state_from_parts!
        @builds << failed_first.build_instance
      end
      it { should == '100%' }
    end

    context "when not all parts ever passed" do
      before do
        never_passed = FactoryGirl.create(:build_attempt, :state => 'failed')
        FactoryGirl.create(:build_attempt, :state => 'failed', :build_part => never_passed.build_part)
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

  describe 'average_number_of_rebuilds' do
    subject { helper.average_number_of_rebuilds(@builds) }

    before do
      # setup test with successful two builds containing varying build attempts
      ba = FactoryGirl.create(:build_attempt, :state => 'errored')
      FactoryGirl.create(:build_attempt, :state => 'failed', :build_part => ba.build_part)
      FactoryGirl.create(:build_attempt, :state => 'passed', :build_part => ba.build_part)
      ba.build_instance.update_state_from_parts!
      @builds << ba.build_instance

      ba = FactoryGirl.create(:build_attempt, :state => 'failed')
      FactoryGirl.create(:build_attempt, :state => 'passed', :build_part => ba.build_part)
      ba.build_instance.update_state_from_parts!
      @builds << ba.build_instance
    end

    it { should == 1.5 }

    context 'when there is an unsuccessful build' do
      before do
        ba = FactoryGirl.create(:build_attempt, :state => 'errored')
        ba.build_instance.update_state_from_parts!
        @builds << ba.build_instance
      end

      it 'should not impact the result' do
        should == 1.5
      end
    end
  end

  describe 'median_elapsed_time' do
    subject { helper.median_elapsed_time(@builds) }

    before do
      5.times do |i|
        @builds << build = FactoryGirl.create(:build, :state => 'succeeded', :created_at => (10 + 5 * i).minutes.ago)
        build_part = FactoryGirl.create(:build_part, :build_instance => build)
        FactoryGirl.create(:build_attempt, :build_part => build_part, :finished_at => build.created_at + (3 * i).minutes)
      end
    end

    it { should be_within(1).of(6 * 60) }

    context 'when there is an unsuccessful build' do
      before do
        ba = FactoryGirl.create(:build_attempt, :state => 'errored')
        ba.build_instance.update_state_from_parts!
        @builds << ba.build_instance
      end

      it 'should not impact the result' do
        should be_within(1).of(6 * 60)
      end
    end

    context 'when there is an even number of builds' do
      before do
        @builds << build = FactoryGirl.create(:build, :state => 'succeeded', :created_at => 45.minutes.ago)
        build_part = FactoryGirl.create(:build_part, :build_instance => build)
        FactoryGirl.create(:build_attempt, :build_part => build_part, :finished_at => build.created_at + 17.minutes)
      end

      it 'should average the middle two' do
        should be_within(1).of((6 + 9) * 30)
      end
    end
  end
end
