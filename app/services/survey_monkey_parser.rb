class SurveyMonkeyParser
  attr_reader :survey, :responses

  def initialize(data)
    @survey = Survey.new(data)
    @responses = data.dig('responses', 'data') || []
  end

  def parse_responses
    responses.map do |response|
      ResponseParser.new(response, survey).parse
    end
  end

  class Survey
    def initialize(data)
      @data = data
    end

    def language
      data['language']
    end

    def commentable_question?(question)
      question['family'] == 'open_ended' && question['subtype'] == 'essay'
    end

    def qualifiable_question?(question)
      question['family'] == 'matrix' && question['subtype'] == 'rating'
    end

    def find_question(id)
      questions.find { |q| q['id'] == id }
    end

    private

    attr_reader :data

    def questions
      @questions ||= data['pages'].map { |page| page['questions'] }.flatten
    end
  end

  class ResponseParser
    ATTRIBUTES = %w(score comment response_id survey_id created_at collector_id custom_variables url language).freeze

    def initialize(data, survey)
      @data = data
      @survey = survey
    end

    def parse
      ATTRIBUTES.inject({}) { |acc, elem| acc.merge(elem => send(elem)) }
    end

    private

    attr_reader :data, :survey

    def score
      question = questions.find { |q| survey.qualifiable_question?(q['details']) }
      return if question.nil?

      choices = question.dig('details', 'answers', 'choices')
      values = question['answers'].map do |answer|
        choice = choices.find { |c| c['id'] == answer['choice_id'] }
        choice['text'].to_i
      end

      (values.sum / values.size.to_f).round
    end

    def comment
      question = questions.find { |q| survey.commentable_question?(q['details']) }
      return if question.nil?

      question['answers'].first['text']
    end

    def response_id
      data['id']
    end

    def survey_id
      data['survey_id']
    end

    def created_at
      data['date_created']
    end

    def collector_id
      data['collector_id']
    end

    def custom_variables
      data['custom_variables']
    end

    def url
      data['analyze_url']
    end

    def language
      survey.language
    end

    def questions
      @questions ||= data['pages']
                     .map { |page| page['questions'] }
                     .flatten
                     .map { |q| q.merge('details' => survey.find_question(q['id'])) }
    end
  end
end
