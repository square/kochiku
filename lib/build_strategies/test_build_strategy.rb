class BuildStrategy
  class << self
    def execute_build(build_kind, test_files)
      true
    end

    def promote_build(build_ref)
    end

    def artifacts_glob
      []
    end
  end
end
