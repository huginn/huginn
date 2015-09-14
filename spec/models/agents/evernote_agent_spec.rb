require 'spec_helper'

describe Agents::EvernoteAgent do

  let(:note_store) do
    class FakeEvernoteNoteStore
      attr_accessor :notes, :tags, :notebooks
      def initialize
        @notes, @tags, @notebooks = [], [], []
      end

      def createNote(note)
        note.attributes = OpenStruct.new(source: nil, sourceURL: nil)
        note.guid = @notes.length + 1
        @notes << note
        note
      end

      def updateNote(note)
        note.attributes = OpenStruct.new(source: nil, sourceURL: nil)
        old_note = @notes.find {|en_note| en_note.guid == note.guid}
        @notes[@notes.index(old_note)] = note
        note
      end

      def getNote(guid, *other_args)
        @notes.find {|note| note.guid == guid}
      end

      def createNotebook(notebook)
        notebook.guid = @notebooks.length + 1
        @notebooks << notebook
        notebook
      end

      def createTag(tag)
        tag.guid = @tags.length + 1
        @tags << tag
        tag
      end

      def listNotebooks; @notebooks; end

      def listTags; @tags; end

      def getNoteTagNames(guid)
        getNote(guid).try(:tagNames) || []
      end

      def findNotesMetadata(*args); end
    end

    note_store = FakeEvernoteNoteStore.new
    stub.any_instance_of(Agents::EvernoteAgent).evernote_note_store { note_store }
    note_store
  end

  describe "#receive" do
    context "when mode is set to 'update'" do
      before do
        @options = {
          :mode => "update",
          :include_xhtml_content => "false",
          :expected_update_period_in_days => "2",
          :note => {
            :title     => "{{title}}",
            :content   => "{{content}}",
            :notebook  => "{{notebook}}",
            :tagNames  => "{{tag1}}, {{tag2}}"
          }
        }
        @agent = Agents::EvernoteAgent.new(:name => "evernote updater", :options => @options)
        @agent.service = services(:generic)
        @agent.user = users(:bob)
        @agent.save!

        @event = Event.new
        @event.agent = agents(:bob_website_agent)
        @event.payload = { :title => "xkcd Survey",
                           :content => "The xkcd Survey: Big Data for a Big Planet",
                           :notebook => "xkcd",
                           :tag1 => "funny",
                           :tag2 => "data" }
        @event.save!

        tag1 = OpenStruct.new(name: "funny")
        tag2 = OpenStruct.new(name: "data")
        [tag1, tag2].each { |tag| note_store.createTag(tag) }
      end

      it "adds a note for any payload it receives" do
        stub(note_store).findNotesMetadata { OpenStruct.new(notes: []) }
        Agents::EvernoteAgent.async_receive(@agent.id, [@event.id])

        expect(note_store.notes.size).to eq(1)
        expect(note_store.notes.first.title).to eq("xkcd Survey")
        expect(note_store.notebooks.size).to eq(1)
        expect(note_store.tags.size).to eq(2)
        
        expect(@agent.events.count).to eq(1)
        expect(@agent.events.first.payload).to eq({
          "title" => "xkcd Survey",
          "notebook" => "xkcd",
          "tags" => ["funny", "data"],
          "source" => nil,
          "source_url" => nil
        })
      end

      context "a note with the same title and notebook exists" do
        before do
          note1 = OpenStruct.new(title: "xkcd Survey", notebookGuid: 1)
          note2 = OpenStruct.new(title: "Footprints", notebookGuid: 1)
          [note1, note2].each { |note| note_store.createNote(note) }
          note_store.createNotebook(OpenStruct.new(name: "xkcd"))

          stub(note_store).findNotesMetadata {
            OpenStruct.new(notes: [note1]) }
        end

        it "updates the existing note" do
          Agents::EvernoteAgent.async_receive(@agent.id, [@event.id])

          expect(note_store.notes.size).to eq(2)
          expect(note_store.getNote(1).tagNames).to eq(["funny", "data"])
          expect(@agent.events.count).to eq(1)
        end
      end

      context "include_xhtml_content is set to 'true'" do
        before do
          @agent.options[:include_xhtml_content] = "true"
          @agent.save!
        end

        it "creates an event with note content wrapped in ENML" do
          stub(note_store).findNotesMetadata { OpenStruct.new(notes: []) }
          Agents::EvernoteAgent.async_receive(@agent.id, [@event.id])

          payload = @agent.events.first.payload

          expect(payload[:content]).to eq(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" \
            "<!DOCTYPE en-note SYSTEM \"http://xml.evernote.com/pub/enml2.dtd\">" \
            "<en-note>The xkcd Survey: Big Data for a Big Planet</en-note>"
          )
        end
      end
    end
  end

  describe "#check" do
    context "when mode is set to 'read'" do
      before do
        @options = {
          :mode => "read",
          :include_xhtml_content => "false",
          :expected_update_period_in_days => "2",
          :note => {
            :title     => "",
            :content   => "",
            :notebook  => "xkcd",
            :tagNames  => "funny, comic"
          }
        }
        @checker = Agents::EvernoteAgent.new(:name => "evernote reader", :options => @options)

        @checker.service = services(:generic)
        @checker.user = users(:bob)
        @checker.schedule = "every_2h"

        @checker.save!
        @checker.created_at = 1.minute.ago

        note_store.createNote(
          OpenStruct.new(title: "xkcd Survey",
                         notebookGuid: 1,
                         updated: 2.minutes.ago.to_i * 1000,
                         tagNames: ["funny", "comic"])
        )
        note_store.createNotebook(OpenStruct.new(name: "xkcd"))
        tag1 = OpenStruct.new(name: "funny")
        tag2 = OpenStruct.new(name: "comic")
        [tag1, tag2].each { |tag| note_store.createTag(tag) }

        stub(note_store).findNotesMetadata {
          notes = note_store.notes.select do |note|
            note.notebookGuid == 1 &&
            %w(funny comic).all? { |tag_name| note.tagNames.include?(tag_name) }
          end
          OpenStruct.new(notes: notes)
        }
      end

      context "the first time it checks" do
        it "returns only notes created/updated since it was created" do
          expect { @checker.check }.to change { Event.count }.by(0)
        end
      end

      context "on subsequent checks" do
        it "returns notes created/updated since the last time it checked" do
          expect { @checker.check }.to change { Event.count }.by(0)

          future_time = (Time.now + 1.minute).to_i * 1000
          note_store.createNote(
            OpenStruct.new(title: "Footprints",
                           notebookGuid: 1,
                           tagNames: ["funny", "comic", "recent"],
                           updated: future_time))

          note_store.createNote(
            OpenStruct.new(title: "something else",
                           notebookGuid: 2,
                           tagNames: ["funny", "comic"],
                           updated: future_time))

          expect { @checker.check }.to change { Event.count }.by(1)
        end

        it "returns notes tagged since the last time it checked" do
          note_store.createNote(
            OpenStruct.new(title: "Footprints",
                           notebookGuid: 1,
                           tagNames: [],
                           created: Time.now.to_i * 1000,
                           updated: Time.now.to_i * 1000))
          @checker.check

          note_store.getNote(2).tagNames = ["funny", "comic"]

          expect { @checker.check }.to change { Event.count }.by(1)
        end
      end
    end
  end

  describe "#validation" do
    before do
      @options = {
        :mode => "update",
        :include_xhtml_content => "false",
        :expected_update_period_in_days => "2",
        :note => {
          :title     => "{{title}}",
          :content   => "{{content}}",
          :notebook  => "{{notebook}}",
          :tagNames  => "{{tag1}}, {{tag2}}"
        }
      }
      @agent = Agents::EvernoteAgent.new(:name => "evernote updater", :options => @options)
      @agent.service = services(:generic)
      @agent.user = users(:bob)
      @agent.save!

      expect(@agent).to be_valid
    end

    it "requires the mode to be 'update' or 'read'" do
      @agent.options[:mode] = ""
      expect(@agent).not_to be_valid
    end

    context "mode is set to 'update'" do
      before do
        @agent.options[:mode] = "update"
      end

      it "requires some note parameter to be present" do
        @agent.options[:note].keys.each { |k| @agent.options[:note][k] = "" }
        expect(@agent).not_to be_valid
      end

      it "requires schedule to be 'never'" do
        @agent.schedule = 'never'
        expect(@agent).to be_valid

        @agent.schedule = 'every_1m'
        expect(@agent).not_to be_valid
      end
    end

    context "mode is set to 'read'" do
      before do
        @agent.options[:mode] = "read"
      end

      it "requires a schedule to be set" do
        @agent.schedule = 'every_1m'
        expect(@agent).to be_valid

        @agent.schedule = 'never'
        expect(@agent).not_to be_valid
      end
    end
  end
end
