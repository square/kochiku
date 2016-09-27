module CommonHelper
  BUILD_WAIT_TIME_PCTL_MAP = {
    ninety_five_pctl_build_wait_time: '0.95',
    ninety_pctl_build_wait_time: '0.9',
    seventy_pctl_build_wait_time: '0.7',
    fifty_pctl_build_wait_time: '0.5'
  }.freeze

  BUILD_RUN_TIME_PCTL_MAP = {
    ninety_five_pctl_build_run_time: '0.95',
    ninety_pctl_build_run_time: '0.9',
    seventy_pctl_pctl_build_run_time: '0.7',
    fifty_pctl_build_run_time: '0.5'
  }.freeze

  def filter_time_range(options={})
    start_time = options[:start_time] || DateTime.new(1970, 1, 1).utc
    end_time = options[:end_time] || DateTime.current
    start_time..end_time
  end
end
