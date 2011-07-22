class BuildStrategy
  class << self
    def execute_build(build_part)
      system "env -i HOME=$HOME"+
      " PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/X11/bin"+
      " TEST_RUNNER=#{build_part.kind}"+
      " RUN_LIST=#{build_part.paths.join(',')}"+
      " bash --noprofile --norc -c 'ruby -v ; source ~/.rvm/scripts/rvm ; rvm use ree ; mkdir log ; script/ci worker 2>log/stderr.log 1>log/stdout.log'"
    end

    def promote_build(build)
      system "git push -f destination #{build.ref}:refs/heads/#{promotion_ref}"
    end

    def artifacts_glob
      ['log/*log']
    end

    def promotion_ref
      "ci-kochiku-latest"
    end
  end
end
