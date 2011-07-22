class BuildStrategy
  class << self
    def execute_build(build_part)
      true
    end

    def promote_build(build)
    end

    def artifacts_glob
      []
    end
  end
end
