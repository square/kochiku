require 'spec_helper'

describe StatusController do

  describe "#available" do
    context "when the site is available" do
      it "should return 200" do
        get :available
        expect(response.code).to eq("200")
      end
    end

    context "when the site is unavailable" do
      it "should return 503" do
        expect(File).to receive(:exist?).and_return(true)
        get :available
        expect(response.code).to eq("503")
      end
    end
  end

end
