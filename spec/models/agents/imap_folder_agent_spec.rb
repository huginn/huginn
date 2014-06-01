require 'spec_helper'
require 'time'

describe Agents::ImapFolderAgent do
  describe 'checking IMAP' do
    before do
      @site = {
        'expected_update_period_in_days' => 1,
        'host' => 'mail.example.net',
        'ssl' => true,
        'username' => 'foo',
        'password' => 'bar',
        'folders' => ['INBOX'],
        'conditions' => {
        }
      }
      @checker = Agents::ImapFolderAgent.new(:name => 'Example', :options => @site, :keep_events_for => 2)
      @checker.user = users(:bob)
      @checker.save!

      message_mixin = Module.new {
        def folder
          'INBOX'
        end

        def uidvalidity
          '100'
        end

        def has_attachment?
          false
        end

        def body_parts(mime_types = %[text/plain text/enriched text/html])
          mime_types.map { |type|
            all_parts.find { |part|
              part.mime_type == type
            }
          }.compact
        end
      }

      @mails = [
        Mail.read(Rails.root.join('spec/data_fixtures/imap1.eml')).tap { |mail|
          mail.extend(message_mixin)
          stub(mail).uid.returns(1)
        },
        Mail.read(Rails.root.join('spec/data_fixtures/imap2.eml')).tap { |mail|
          mail.extend(message_mixin)
          stub(mail).uid.returns(2)
          stub(mail).has_attachment?.returns(true)
        },
      ]

      stub(@checker).each_unread_mail.returns { |yielder|
        @mails.each(&yielder)
      }

      @payloads = [
        {
          'folder' => 'INBOX',
          'from' => 'nanashi.gombeh@example.jp',
          'to' => ['jane.doe@example.com', 'john.doe@example.com'],
          'cc' => [],
          'date' => '2014-05-09T16:00:00+09:00',
          'subject' => 'some subject',
          'body' => "Some plain text\nSome second line\n",
          'has_attachment' => false,
          'matches' => {},
          'mime_type' => 'text/plain',
        },
        {
          'folder' => 'INBOX',
          'from' => 'john.doe@example.com',
          'to' => ['jane.doe@example.com', 'nanashi.gombeh@example.jp'],
          'cc' => [],
          'subject' => 'Re: some subject',
          'body' => "Some reply\n",
          'date' => '2014-05-09T17:00:00+09:00',
          'has_attachment' => true,
          'matches' => {},
          'mime_type' => 'text/plain',
        }
      ]
    end

    describe 'validations' do
      before do
        @checker.should be_valid
      end

      it 'should validate the integer fields' do
        @checker.options['expected_update_period_in_days'] = 'nonsense'
        @checker.should_not be_valid

        @checker.options['expected_update_period_in_days'] = '2'
        @checker.should be_valid

        @checker.options['port'] = -1
        @checker.should_not be_valid

        @checker.options['port'] = 'imap'
        @checker.should_not be_valid

        @checker.options['port'] = '143'
        @checker.should be_valid

        @checker.options['port'] = 993
        @checker.should be_valid
      end

      it 'should validate the boolean fields' do
        @checker.options['ssl'] = false
        @checker.should be_valid

        @checker.options['ssl'] = 'true'
        @checker.should_not be_valid
      end

      it 'should validate regexp conditions' do
        @checker.options['conditions'] = {
          'subject' => '(foo'
        }
        @checker.should_not be_valid

        @checker.options['conditions'] = {
          'body' => '***'
        }
        @checker.should_not be_valid

        @checker.options['conditions'] = {
          'subject' => '\ARe:',
          'body' => '(?<foo>http://\S+)'
        }
        @checker.should be_valid
      end
    end

    describe '#check' do
      it 'should check for mails and save memory' do
        lambda { @checker.check }.should change { Event.count }.by(2)
        @checker.memory['notified'].sort.should == @mails.map(&:message_id).sort
        @checker.memory['seen'].should == @mails.each_with_object({}) { |mail, seen|
          (seen[mail.uidvalidity] ||= []) << mail.uid
        }

        Event.last(2).map(&:payload) == @payloads

        lambda { @checker.check }.should_not change { Event.count }
      end

      it 'should narrow mails by To' do
        @checker.options['conditions']['to'] = 'John.Doe@*'

        lambda { @checker.check }.should change { Event.count }.by(1)
        @checker.memory['notified'].sort.should == [@mails.first.message_id]
        @checker.memory['seen'].should == @mails.each_with_object({}) { |mail, seen|
          (seen[mail.uidvalidity] ||= []) << mail.uid
        }

        Event.last.payload.should == @payloads.first

        lambda { @checker.check }.should_not change { Event.count }
      end

      it 'should perform regexp matching and save named captures' do
        @checker.options['conditions'].update(
          'subject' => '\ARe: (?<a>.+)',
          'body'    => 'Some (?<b>.+) reply',
        )

        lambda { @checker.check }.should change { Event.count }.by(1)
        @checker.memory['notified'].sort.should == [@mails.last.message_id]
        @checker.memory['seen'].should == @mails.each_with_object({}) { |mail, seen|
          (seen[mail.uidvalidity] ||= []) << mail.uid
        }

        Event.last.payload.should == @payloads.last.update(
          'body' => "<div dir=\"ltr\">Some HTML reply<br></div>\n",
          'matches' => { 'a' => 'some subject', 'b' => 'HTML' },
          'mime_type' => 'text/html',
        )

        lambda { @checker.check }.should_not change { Event.count }
      end

      it 'should narrow mails by has_attachment (true)' do
        @checker.options['conditions']['has_attachment'] = true

        lambda { @checker.check }.should change { Event.count }.by(1)

        Event.last.payload['subject'].should == 'Re: some subject'
      end

      it 'should narrow mails by has_attachment (false)' do
        @checker.options['conditions']['has_attachment'] = false

        lambda { @checker.check }.should change { Event.count }.by(1)

        Event.last.payload['subject'].should == 'some subject'
      end

      it 'should narrow mail parts by MIME types' do
        @checker.options['mime_types'] = %w[text/plain]
        @checker.options['conditions'].update(
          'subject' => '\ARe: (?<a>.+)',
          'body'    => 'Some (?<b>.+) reply',
        )

        lambda { @checker.check }.should_not change { Event.count }
        @checker.memory['notified'].sort.should == []
        @checker.memory['seen'].should == @mails.each_with_object({}) { |mail, seen|
          (seen[mail.uidvalidity] ||= []) << mail.uid
        }
      end

      it 'should never mark mails as read unless mark_as_read is true' do
        @mails.each { |mail|
          stub(mail).mark_as_read.never
        }
        lambda { @checker.check }.should change { Event.count }.by(2)
      end

      it 'should mark mails as read if mark_as_read is true' do
        @checker.options['mark_as_read'] = true
        @mails.each { |mail|
          stub(mail).mark_as_read.once
        }
        lambda { @checker.check }.should change { Event.count }.by(2)
      end

      it 'should create just one event for multiple mails with the same Message-Id' do
        @mails.first.message_id = @mails.last.message_id
        @checker.options['mark_as_read'] = true
        @mails.each { |mail|
          stub(mail).mark_as_read.once
        }
        lambda { @checker.check }.should change { Event.count }.by(1)
      end
    end
  end
end
