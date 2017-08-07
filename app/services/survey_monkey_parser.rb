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
    ATTRIBUTES = %w(score comment id survey_id date_created collector_id custom_variables analyze_url language).freeze

    def initialize(data, survey)
      @data = OpenStruct.new(data)
      @survey = survey
    end

    def parse
      ATTRIBUTES.inject({}) { |acc, elem| acc.merge(elem => send(elem)) }
    end

    private

    attr_reader :survey, :data

    delegate :id, :date_created, :survey_id, :collector_id, :custom_variables, :analyze_url, to: :data
    delegate :language, to: :survey

    def score
      return parsed_score_answer unless score_question.nil?
    end

    def comment
      return parsed_comment_answer unless comment_question.nil?
    end

    def questions
      @questions ||= data['pages']
                     .map { |page| page['questions'] }
                     .flatten
                     .map { |q| q.merge('details' => survey.find_question(q['id'])) }
    end

    def score_question
      questions.find { |q| survey.qualifiable_question?(q['details']) }
    end

    def score_options
      score_question.dig('details', 'answers', 'choices')
    end

    def score_answer_given
      score_question['answers'].first['choice_id']
    end

    def parsed_score_answer
      score_options.find { |c| c['id'] == score_answer_given }['text'].gsub(/[^0-9]/, '').to_i
    end

    def comment_question
      questions.find { |q| survey.commentable_question?(q['details']) }
    end

    def comment_answer_given
      comment_question['answers'].first
    end

    def parsed_comment_answer
      comment_answer_given['text']
    end
  end
end
