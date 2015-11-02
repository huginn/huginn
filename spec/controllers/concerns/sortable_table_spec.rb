require 'rails_helper'

describe SortableTable do
  class SortableTestController
    attr_accessor :params

    def self.helper(foo)
    end

    include SortableTable

    public :set_table_sort
    public :table_sort
  end

  describe "#set_table_sort" do
    let(:controller) { SortableTestController.new }
    let(:default) { { column2: :asc }}
    let(:options) { { sorts: %w[column1 column2], default: default } }

    it "uses a default when no sort is given" do
      controller.params = {}
      controller.set_table_sort options
      expect(controller.table_sort).to eq(default)
    end

    it "applies the given sort when one is passed in" do
      controller.params = { sort: "column1.desc" }
      controller.set_table_sort options
      expect(controller.table_sort).to eq({ column1: :desc })

      controller.params = { sort: "column1.asc" }
      controller.set_table_sort options
      expect(controller.table_sort).to eq({ column1: :asc })

      controller.params = { sort: "column2.desc" }
      controller.set_table_sort options
      expect(controller.table_sort).to eq({ column2: :desc })
    end

    it "ignores unknown directions" do
      controller.params = { sort: "column1.foo" }
      controller.set_table_sort options
      expect(controller.table_sort).to eq({ column1: :asc })

      controller.params = { sort: "column1.foo drop tables" }
      controller.set_table_sort options
      expect(controller.table_sort).to eq({ column1: :asc })
    end

    it "ignores unknown columns" do
      controller.params = { sort: "foo.asc" }
      controller.set_table_sort options
      expect(controller.table_sort).to eq(default)

      controller.params = { sort: ";drop table;.asc" }
      controller.set_table_sort options
      expect(controller.table_sort).to eq(default)
    end
  end
end
