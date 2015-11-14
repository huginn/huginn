require 'rails_helper'

describe LiquidDroppable do
  before do
    class DroppableTest
      include LiquidDroppable

      def initialize(value)
        @value = value
      end

      attr_reader :value

      def to_s
        "[value:#{value}]"
      end
    end

    class DroppableTestDrop
      def value
        @object.value
      end
    end
  end

  describe 'test class' do
    it 'should be droppable' do
      five = DroppableTest.new(5)
      expect(five.to_liquid.class).to eq(DroppableTestDrop)
      expect(Liquid::Template.parse('{{ x.value | plus:3 }}').render('x' => five)).to eq('8')
      expect(Liquid::Template.parse('{{ x }}').render('x' => five)).to eq('[value:5]')
    end
  end
end
