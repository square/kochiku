class GitBlame
  class << self
    def emails_since_last_green(build)
      ['test@example.com']
    end

    def emails_in_branch(build)
      ['test@example.com']
    end

    def last_email_in_branch(build)
      ['test@example.com']
    end

    def changes_since_last_green(build)
      [{:hash=>"fed2d1188b2005eea51b3d87f819b2ebbdbeb67a",
        :author=>"Joshua Eversmann <jeversmann@squareup.com>",
        :date=>"Wed Jul 2 15:13:31 2014 -0700",
        :message=>
      "Run success script built back in, Thread checks removed from repo logic"},
        {:hash=>"a556abc734b7fc284436270bce5c52a409b58fb8",
         :author=>"Joshua Eversmann <jeversmann@squareup.com>",
         :date=>"Mon Jun 30 17:22:12 2014 -0700",
         :message=>"This is a\n multi line commit message\n so ha."},
         {:hash=>"7abb9c3194ed1793e78a2928c793d9f4172afab2",
          :author=>"Joshua Eversmann <jeversmann@squareup.com>",
          :date=>"Mon Jun 30 17:22:12 2014 -0700",
          :message=>"Put file reading logic into GitRepo"}]
    end

    def changes_in_branch(build)
      [{:hash=>"fed2d1188b2005eea51b3d87f819b2ebbdbeb67a",
        :author=>"Joshua Eversmann <jeversmann@squareup.com>",
        :date=>"Wed Jul 2 15:13:31 2014 -0700",
        :message=>
      "Run success script built back in, Thread checks removed from repo logic"},
        {:hash=>"a556abc734b7fc284436270bce5c52a409b58fb8",
         :author=>"Joshua Eversmann <jeversmann@squareup.com>",
         :date=>"Mon Jun 30 17:22:12 2014 -0700",
         :message=>"This is a\n multi line commit message\n so ha."},
         {:hash=>"7abb9c3194ed1793e78a2928c793d9f4172afab2",
          :author=>"Joshua Eversmann <jeversmann@squareup.com>",
          :date=>"Mon Jun 30 17:22:12 2014 -0700",
          :message=>"Put file reading logic into GitRepo"}]
    end
  end
end

class Partitioner
  def self.for_build(build)
    Base.new(build, nil)
  end

  class Base
    def initialize(build, kochiku_yml)
      @build = build
      @kochiku_yml = kochiku_yml
    end

    def partitions
      [
        {
          'type' => 'test',
          'files' => ['no-manifest'],
          'queue' => @build.project.main? ? 'ci' : 'developer',
          'retry_count' => 0
        }
      ]
    end

    def emails_for_commits_causing_failures
      {}
    end
  end
end

class BuildMailerPreview < ActionMailer::Preview
  def build_break_email
    BuildMailer.build_break_email(Build.where(:state => :errored).first)
  end
  def build_success_email
    BuildMailer.build_success_email(Build.where(:state => :succeeded).first)
  end
end
