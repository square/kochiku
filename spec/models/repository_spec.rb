require 'spec_helper'

describe Repository do
  it "serializes options" do
    repository = Factory.create(:repository, :options => {'tmp_dir' => 'web-cache'})
    repository.reload
    repository.options.should == {'tmp_dir' => 'web-cache'}
  end
end
