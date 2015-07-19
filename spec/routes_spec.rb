require 'spec_helper'

RSpec.describe "routes", :type => :routing do

  context "branches at" do
    describe '/:repository_path/:id' do
      it 'to branch show page' do
        expect(:get => "/org_name/repo_name/bug-fix").to route_to(
          :controller => "branches",
          :action => "show",
          :repository_path => "org_name/repo_name",
          :id => "bug-fix"
        )
      end

      it 'to support branch names with slashes' do
        expect(:get => "/org_name/repo_name/rob/bug-fix").to route_to(
          :controller => "branches",
          :action => "show",
          :repository_path => "org_name/repo_name",
          :id => "rob/bug-fix"
        )
      end

      it 'to support branch names with dots' do
        expect(:get => "/org_name/repo_name/rob.bug-fix").to route_to(
          :controller => "branches",
          :action => "show",
          :repository_path => "org_name/repo_name",
          :id => "rob.bug-fix"
        )
      end
    end

    describe '/:repository_path/:id member routes' do
      it 'to a sub page' do
        expect(:get => "/org_name/repo_name/bug-fix/health").to route_to(
          :controller => "branches",
          :action => "health",
          :repository_path => "org_name/repo_name",
          :id => "bug-fix"
        )
      end

      it 'to support branch names with slashes' do
        expect(:get => "/org_name/repo_name/rob/bug-fix/health").to route_to(
          :controller => "branches",
          :action => "health",
          :repository_path => "org_name/repo_name",
          :id => "rob/bug-fix"
        )
      end

      it 'to support branch names with dots' do
        expect(:get => "/org_name/repo_name/rob.bug-fix/health").to route_to(
          :controller => "branches",
          :action => "health",
          :repository_path => "org_name/repo_name",
          :id => "rob.bug-fix"
        )
      end
    end
  end
end
