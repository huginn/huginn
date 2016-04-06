module JobsHelper

  def status(job)
    case
    when job.failed_at
      content_tag :span, 'failed', class: 'label label-danger'
    when job.locked_at && job.locked_by
      content_tag :span, 'running', class: 'label label-info'
    else
      content_tag :span, 'queued', class: 'label label-warning'
    end
  end

  def relative_distance_of_time_in_words(time)
    if time < (now = Time.now)
      time_ago_in_words(time) + ' ago'
    else
      'in ' + distance_of_time_in_words(time, now)
    end
  end

  # Given an queued job, parse the stored YAML to retrieve the ID of the Agent
  # meant to be ran.
  #
  # Can return nil, or an instance of Agent.
  def agent_from_job(job)
    if data = YAML.load(job.handler.to_s).try(:job_data)
      Agent.find_by_id(data['arguments'][0])
    else
      false
    end
  rescue ArgumentError
    # We can get to this point before all of the agents have loaded (usually,
    # in development)
    nil
  end
end
