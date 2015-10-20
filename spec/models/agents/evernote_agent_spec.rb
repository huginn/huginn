require 'rails_helper'

describe Agents::EvernoteAgent do
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

  let(:en_note_store) do
    FakeEvernoteNoteStore.new
  end

  before do
    stub.any_instance_of(Agents::EvernoteAgent).evernote_note_store { en_note_store }
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
        [tag1, tag2].each { |tag| en_note_store.createTag(tag) }
      end

      it "adds a note for any payload it receives" do
        stub(en_note_store).findNotesMetadata { OpenStruct.new(notes: []) }
        Agents::EvernoteAgent.async_receive(@agent.id, [@event.id])

        expect(en_note_store.notes.size).to eq(1)
        expect(en_note_store.notes.first.title).to eq("xkcd Survey")
        expect(en_note_store.notebooks.size).to eq(1)
        expect(en_note_store.tags.size).to eq(2)

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
          [note1, note2].each { |note| en_note_store.createNote(note) }
          en_note_store.createNotebook(OpenStruct.new(name: "xkcd"))

          stub(en_note_store).findNotesMetadata {
            OpenStruct.new(notes: [note1]) }
        end

        it "updates the existing note" do
          Agents::EvernoteAgent.async_receive(@agent.id, [@event.id])

          expect(en_note_store.notes.size).to eq(2)
          expect(en_note_store.getNote(1).tagNames).to eq(["funny", "data"])
          expect(@agent.events.count).to eq(1)
        end
      end

      context "include_xhtml_content is set to 'true'" do
        before do
          @agent.options[:include_xhtml_content] = "true"
          @agent.save!
        end

        it "creates an event with note content wrapped in ENML" do
          stub(en_note_store).findNotesMetadata { OpenStruct.new(notes: []) }
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

        en_note_store.createNote(
          OpenStruct.new(title: "xkcd Survey",
                         notebookGuid: 1,
                         updated: 2.minutes.ago.to_i * 1000,
                         tagNames: ["funny", "comic"])
        )
        en_note_store.createNotebook(OpenStruct.new(name: "xkcd"))
        tag1 = OpenStruct.new(name: "funny")
        tag2 = OpenStruct.new(name: "comic")
        [tag1, tag2].each { |tag| en_note_store.createTag(tag) }

        stub(en_note_store).findNotesMetadata {
          notes = en_note_store.notes.select do |note|
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
          en_note_store.createNote(
            OpenStruct.new(title: "Footprints",
                           notebookGuid: 1,
                           tagNames: ["funny", "comic", "recent"],
                           updated: future_time))

          en_note_store.createNote(
            OpenStruct.new(title: "something else",
                           notebookGuid: 2,
                           tagNames: ["funny", "comic"],
                           updated: future_time))

          expect { @checker.check }.to change { Event.count }.by(1)
        end

        it "returns notes tagged since the last time it checked" do
          en_note_store.createNote(
            OpenStruct.new(title: "Footprints",
                           notebookGuid: 1,
                           tagNames: [],
                           created: Time.now.to_i * 1000,
                           updated: Time.now.to_i * 1000))
          @checker.check

          en_note_store.getNote(2).tagNames = ["funny", "comic"]

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

  # api wrapper classes
  describe Agents::EvernoteAgent::NoteStore do
    let(:note_store) { Agents::EvernoteAgent::NoteStore.new(en_note_store) }

    let(:note1) { OpenStruct.new(title: "first note") }
    let(:note2) { OpenStruct.new(title: "second note") }

    before do
      en_note_store.createNote(note1)
      en_note_store.createNote(note2)
    end

    describe "#create_note" do
      it "creates a note with given params in evernote note store" do
        note_store.create_note(title: "third note")

        expect(en_note_store.notes.size).to eq(3)
        expect(en_note_store.notes.last.title).to eq("third note")
      end

      it "returns a note" do
        expect(note_store.create_note(title: "third note")).to be_a(Agents::EvernoteAgent::Note)
      end
    end

    describe "#update_note" do
      it "updates an existing note with given params" do
        note_store.update_note(guid: 1, content: "some words")

        expect(en_note_store.notes.first.content).not_to be_nil
        expect(en_note_store.notes.size).to eq(2)
      end

      it "returns a note" do
        expect(note_store.update_note(guid: 1, content: "some words")).to be_a(Agents::EvernoteAgent::Note)
      end
    end

    describe "#find_note" do
      it "gets a note with the given guid" do
        note = note_store.find_note(2)

        expect(note.title).to eq("second note")
        expect(note).to be_a(Agents::EvernoteAgent::Note)
      end
    end

    describe "#find_tags" do
      let(:tag1) { OpenStruct.new(name: "tag1") }
      let(:tag2) { OpenStruct.new(name: "tag2") }
      let(:tag3) { OpenStruct.new(name: "tag3") }

      before do
        [tag1, tag2, tag3].each { |tag| en_note_store.createTag(tag) }
      end

      it "finds tags with the given guids" do
        expect(note_store.find_tags([1,3])).to eq([tag1, tag3])
      end
    end

    describe "#find_notebook" do
      let(:notebook1) { OpenStruct.new(name: "notebook1") }
      let(:notebook2) { OpenStruct.new(name: "notebook2") }

      before do
        [notebook1, notebook2].each {|notebook| en_note_store.createNotebook(notebook)}
      end

      it "finds a notebook with given name" do
        expect(note_store.find_notebook(name: "notebook1")).to eq(notebook1)
        expect(note_store.find_notebook(name: "notebook3")).to be_nil
      end

      it "finds a notebook with a given guid" do
        expect(note_store.find_notebook(guid: 2)).to eq(notebook2)
        expect(note_store.find_notebook(guid: 3)).to be_nil
      end
    end

    describe "#create_or_update_note" do
      let(:notebook1) { OpenStruct.new(name: "first notebook")}

      before do
        en_note_store.createNotebook(notebook1)
      end

      context "a note with given title and notebook does not exist" do
        before do
          stub(en_note_store).findNotesMetadata { OpenStruct.new(notes: []) }
        end

        it "creates a note" do
          result = note_store.create_or_update_note(title: "third note", notebook: "first notebook")

          expect(result).to be_a(Agents::EvernoteAgent::Note)
          expect(en_note_store.getNote(3)).to_not be_nil
        end

        it "also creates the notebook if it does not exist" do
          note_store.create_or_update_note(title: "third note", notebook: "second notebook")

          expect(note_store.find_notebook(name: "second notebook")).to_not be_nil
        end
      end

      context "such a note does exist" do
        let(:note) { OpenStruct.new(title: "a note", notebookGuid: 1) }

        before do
          en_note_store.createNote(note)
          stub(en_note_store).findNotesMetadata { OpenStruct.new(notes: [note]) }
        end

        it "updates the note" do
          prior_note_count = en_note_store.notes.size

          result = note_store.create_or_update_note(
            title: "a note", notebook: "first notebook", content: "test content")

          expect(result).to be_a(Agents::EvernoteAgent::Note)
          expect(en_note_store.notes.size).to eq(prior_note_count)
          expect(en_note_store.getNote(3).content).to include("test content")
        end
      end
    end
  end

  describe Agents::EvernoteAgent::NoteStore::Search do
    let(:note_store) { Agents::EvernoteAgent::NoteStore.new(en_note_store) }

    let(:note1) {
      OpenStruct.new(title: "first note", notebookGuid: 1, tagNames: ["funny", "comic"], updated: Time.now) }
    let(:note2) {
      OpenStruct.new(title: "second note", tagNames: ["funny", "comic"], updated: Time.now) }
    let(:note3) {
      OpenStruct.new(title: "third note", notebookGuid: 1, updated: Time.now - 2.minutes) }

    let(:search) do
      Agents::EvernoteAgent::NoteStore::Search.new(note_store,
        { tagNames: ["funny", "comic"], notebook: "xkcd" })
    end

    let(:search_with_time) do
      Agents::EvernoteAgent::NoteStore::Search.new(note_store,
        { notebook: "xkcd", last_checked_at: Time.now - 1.minute })
    end

    let(:search_with_time_and_tags) do
      Agents::EvernoteAgent::NoteStore::Search.new(note_store,
        { notebook: "xkcd", tagNames: ["funny", "comic"], notes_with_tags: [1], last_checked_at: Time.now - 1.minute })
    end

    before do
      en_note_store.createTag(OpenStruct.new(name: "funny"))
      en_note_store.createTag(OpenStruct.new(name: "comic"))
      en_note_store.createNotebook(OpenStruct.new(name: "xkcd"))

      [note1, note2, note3].each { |note| en_note_store.createNote(note) }
    end

    describe "#note_guids" do
      it "returns the guids of notes satisfying search options" do
        stub(en_note_store).findNotesMetadata { OpenStruct.new(notes: [note1]) }
        result = search.note_guids

        expect(result.size).to eq(1)
        expect(result.first).to eq(1)
      end
    end

    describe "#notes" do
      context "last_checked_at is not set" do
        it "returns notes satisfying the search options" do
          stub(en_note_store).findNotesMetadata { OpenStruct.new(notes: [note1]) }
          result = search.notes

          expect(result.size).to eq(1)
          expect(result.first.title).to eq("first note")
          expect(result.first).to be_a(Agents::EvernoteAgent::Note)
        end
      end

      context "last_checked_at is set" do
        context "notes_with_tags is not set" do
          it "only returns notes updated since then" do
            stub(en_note_store).findNotesMetadata { OpenStruct.new(notes: [note1, note3]) }
            result = search_with_time.notes

            expect(result.size).to eq(1)
            expect(result.first.title).to eq("first note")
          end
        end

        context "notes_with_tags is set" do
          it "returns notes updated since then or notes with recently added tags" do
            note3.tagNames = ["funny", "comic"]
            stub(en_note_store).findNotesMetadata { OpenStruct.new(notes: [note1, note3]) }

            result = search_with_time_and_tags.notes
            expect(result.size).to eq(2)
            expect(result.last.title).to eq("third note")
          end
        end
      end
    end

    describe "#create_filter" do
      it "builds an evernote search filter using search grammar" do
        filter = search.create_filter
        expect(filter.words).to eq("notebook:\"xkcd\" tag:funny tag:comic")
      end
    end
  end

  describe Agents::EvernoteAgent::Note do
    let(:resource) {
      OpenStruct.new(mime: "image/png",
                     attributes: OpenStruct.new(sourceURL: "http://imgs.xkcd.com/comics/xkcd_survey.png", fileName: "xkcd_survey.png"))
    }

    let(:en_note_attributes) {
      OpenStruct.new(source: "web.clip", sourceURL: "http://xkcd.com/1572/")
    }

    let(:en_note) {
      OpenStruct.new(title: "xkcd Survey",
                     tagNames: ["funny", "data"],
                     content: "The xkcd Survey: Big Data for a Big Planet",
                     attributes: en_note_attributes,
                     resources: [resource])
    }

    describe "#attr" do
      let(:note) {
        Agents::EvernoteAgent::Note.new(en_note, "xkcd", ["funny", "data"])
      }

      context "when no option is set" do
        it "returns a hash with title, tags, notebook, source and source url" do
          expect(note.attr).to eq(
            {
              title:        en_note.title,
              notebook:     "xkcd",
              tags:         ["funny", "data"],
              source:       en_note.attributes.source,
              source_url:   en_note.attributes.sourceURL
            }
          )
        end
      end

      context "when include_content is set to true" do
        it "includes content" do
          note_attr = note.attr(include_content: true)

          expect(note_attr[:content]).to eq(
            "The xkcd Survey: Big Data for a Big Planet"
          )
        end
      end

      context "when include_resources is set to true" do
        it "includes resources" do
          note_attr = note.attr(include_resources: true)

          expect(note_attr[:resources].first).to eq(
            {
              url: resource.attributes.sourceURL,
              name:  resource.attributes.fileName,
              mime_type: resource.mime
            }
          )
        end
      end
    end
  end
end
