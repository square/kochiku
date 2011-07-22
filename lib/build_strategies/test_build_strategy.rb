class BuildStrategy
  class << self
    def execute_build(build_part)
      true
    end

    def promote_build(build_ref)
    end

    def artifacts_glob
      []
    end
  end
end
