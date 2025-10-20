# frozen_string_literal: true

RSpec.describe Chat::SearchMessage do
  describe ".call" do
    subject(:result) { described_class.call(**params) }

    fab!(:current_user, :user)
    fab!(:channel, :chat_channel)

    let(:guardian) { Guardian.new(current_user) }
    let(:params) { { guardian: guardian, params: { channel_id: channel.id, query: query } } }
    let(:query) { "test" }

    before do
      channel.add(current_user)
      SiteSetting.chat_enabled = true
      SearchIndexer.enable
    end

    context "when user can view the channel" do
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel, message: "hello world") }
      fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel, message: "test message") }
      fab!(:message_3) { Fabricate(:chat_message, chat_channel: channel, message: "another test") }

      before do
        [message_1, message_2, message_3].each do |message|
          SearchIndexer.index(message, force: true)
        end
      end

      it { is_expected.to be_a_success }

      it "returns matching messages" do
        expect(result.messages).to contain_exactly(message_2, message_3)
      end

      context "when query is blank" do
        let(:query) { "" }

        it { is_expected.to be_a_failure }
      end

      context "when no messages match" do
        let(:query) { "nonexistent" }

        it { is_expected.to be_a_success }

        it "returns no messages" do
          expect(result.messages).to be_empty
        end
      end

      context "with @username filter" do
        fab!(:alice) { Fabricate(:user, username: "alice") }
        fab!(:bob) { Fabricate(:user, username: "bob") }

        fab!(:alice_message_1) do
          Fabricate(:chat_message, chat_channel: channel, user: alice, message: "hello from alice")
        end
        fab!(:alice_message_2) do
          Fabricate(:chat_message, chat_channel: channel, user: alice, message: "testing something")
        end
        fab!(:bob_message) do
          Fabricate(:chat_message, chat_channel: channel, user: bob, message: "hello from bob")
        end

        before do
          [alice_message_1, alice_message_2, bob_message].each do |message|
            SearchIndexer.index(message, force: true)
          end
        end

        context "when searching with @username and term" do
          let(:query) { "@alice hello" }

          it "returns only messages from that user matching the term" do
            expect(result.messages).to contain_exactly(alice_message_1)
          end
        end

        context "when searching with @username only" do
          let(:query) { "@alice" }

          it "returns all messages from that user" do
            expect(result.messages).to contain_exactly(alice_message_1, alice_message_2)
          end
        end

        context "when searching with @me" do
          fab!(:current_user_message) do
            Fabricate(
              :chat_message,
              chat_channel: channel,
              user: current_user,
              message: "my message",
            )
          end

          let(:query) { "@me" }

          before { SearchIndexer.index(current_user_message, force: true) }

          it "returns messages from the current user" do
            expect(result.messages).to contain_exactly(current_user_message)
          end
        end

        context "when username doesn't exist" do
          let(:query) { "@nonexistent hello" }

          it "searches for the literal @nonexistent text" do
            expect(result.messages).to be_empty
          end
        end

        context "when username is case insensitive" do
          let(:query) { "@ALICE hello" }

          it "returns messages from alice regardless of case" do
            expect(result.messages).to contain_exactly(alice_message_1)
          end
        end

        context "with multiple @username filters" do
          let(:query) { "@alice @bob hello" }

          it "returns no results since no message can be from both users" do
            expect(result.messages).to be_empty
          end
        end
      end

      context "with limit parameter" do
        fab!(:message_4) { Fabricate(:chat_message, chat_channel: channel, message: "test four") }
        fab!(:message_5) { Fabricate(:chat_message, chat_channel: channel, message: "test five") }

        let(:params) do
          { guardian: guardian, params: { channel_id: channel.id, query: query, limit: 2 } }
        end

        before do
          [message_4, message_5].each { |message| SearchIndexer.index(message, force: true) }
        end

        it "limits the number of results" do
          expect(result.messages.length).to eq(2)
        end
      end

      context "with pagination" do
        fab!(:message_4) { Fabricate(:chat_message, chat_channel: channel, message: "test four") }
        fab!(:message_5) { Fabricate(:chat_message, chat_channel: channel, message: "test five") }
        fab!(:message_6) { Fabricate(:chat_message, chat_channel: channel, message: "test six") }

        before do
          [message_4, message_5, message_6].each do |message|
            SearchIndexer.index(message, force: true)
          end
        end

        context "with offset parameter" do
          let(:params) do
            { guardian: guardian, params: { channel_id: channel.id, query: query, offset: 2 } }
          end

          it "skips the specified number of results" do
            all_results =
              described_class.call(
                guardian: guardian,
                params: {
                  channel_id: channel.id,
                  query: query,
                },
              ).messages

            expect(result.messages).to eq(all_results.drop(2))
          end
        end

        context "with has_more indicator" do
          context "when there are more results" do
            let(:params) do
              { guardian: guardian, params: { channel_id: channel.id, query: query, limit: 2 } }
            end

            it "sets has_more to true" do
              expect(result.has_more).to be true
            end
          end

          context "when there are no more results" do
            let(:params) do
              { guardian: guardian, params: { channel_id: channel.id, query: query, limit: 10 } }
            end

            it "sets has_more to false" do
              expect(result.has_more).to be false
            end
          end

          context "when offset is used" do
            let(:params) do
              {
                guardian: guardian,
                params: {
                  channel_id: channel.id,
                  query: query,
                  limit: 2,
                  offset: 3,
                },
              }
            end

            it "sets has_more correctly based on remaining results" do
              expect(result.has_more).to be false
            end
          end
        end

        context "with combined offset and limit" do
          let(:params) do
            {
              guardian: guardian,
              params: {
                channel_id: channel.id,
                query: query,
                limit: 2,
                offset: 1,
              },
            }
          end

          it "returns the correct page of results" do
            all_results =
              described_class.call(
                guardian: guardian,
                params: {
                  channel_id: channel.id,
                  query: query,
                },
              ).messages

            expect(result.messages).to eq(all_results[1..2])
          end
        end
      end

      context "with exclude_threads parameter" do
        fab!(:original_message) do
          Fabricate(:chat_message, chat_channel: channel, message: "original test message")
        end
        fab!(:thread) do
          Fabricate(:chat_thread, channel: channel, original_message: original_message)
        end
        fab!(:thread_reply) do
          Fabricate(
            :chat_message,
            chat_channel: channel,
            thread: thread,
            message: "thread reply test",
          )
        end
        fab!(:regular_message) do
          Fabricate(:chat_message, chat_channel: channel, message: "regular test message")
        end

        let(:query) { "test" }

        before do
          [original_message, thread_reply, regular_message].each do |message|
            SearchIndexer.index(message, force: true)
          end
        end

        context "when exclude_threads is false (default)" do
          let(:params) do
            {
              guardian: guardian,
              params: {
                channel_id: channel.id,
                query: query,
                exclude_threads: false,
              },
            }
          end

          it "includes all matching messages including thread replies" do
            expect(result.messages).to include(original_message, thread_reply, regular_message)
          end
        end

        context "when exclude_threads is true" do
          let(:params) do
            {
              guardian: guardian,
              params: {
                channel_id: channel.id,
                query: query,
                exclude_threads: true,
              },
            }
          end

          it "excludes thread replies but keeps original thread messages and regular messages" do
            expect(result.messages).to include(original_message, regular_message)
            expect(result.messages).not_to include(thread_reply)
          end
        end
      end
    end

    context "when user cannot view the channel" do
      fab!(:private_channel, :private_category_channel)

      let(:params) do
        { guardian: guardian, params: { channel_id: private_channel.id, query: query } }
      end

      it { is_expected.to be_a_failure }
    end

    context "when channel doesn't exist" do
      let(:params) { { guardian: guardian, params: { channel_id: -1, query: query } } }

      it { is_expected.to be_a_failure }
    end

    context "with invalid params" do
      context "when channel_id is missing (global search)" do
        fab!(:channel_2, :chat_channel)
        fab!(:private_channel, :private_category_channel)

        fab!(:channel_1_message) do
          Fabricate(:chat_message, chat_channel: channel, message: "global search test")
        end
        fab!(:channel_2_message) do
          Fabricate(:chat_message, chat_channel: channel_2, message: "another global test")
        end
        fab!(:private_channel_message) do
          Fabricate(:chat_message, chat_channel: private_channel, message: "private global test")
        end

        let(:params) { { guardian: guardian, params: { query: "global" } } }
        let(:query) { "global" }

        before do
          channel_2.add(current_user)
          [channel_1_message, channel_2_message, private_channel_message].each do |message|
            SearchIndexer.index(message, force: true)
          end
        end

        it { is_expected.to be_a_success }

        it "returns messages from multiple accessible channels" do
          expect(result.messages).to contain_exactly(channel_1_message, channel_2_message)
        end

        it "excludes messages from inaccessible channels" do
          expect(result.messages).not_to include(private_channel_message)
        end

        it "searches across all accessible channels" do
          expect(result.messages.map(&:chat_channel_id).uniq.sort).to eq(
            [channel.id, channel_2.id].sort,
          )
        end
      end

      context "when limit is too high" do
        let(:params) do
          { guardian: guardian, params: { channel_id: channel.id, query: query, limit: 50 } }
        end

        it { is_expected.to be_a_failure }
      end

      context "when limit is too low" do
        let(:params) do
          { guardian: guardian, params: { channel_id: channel.id, query: query, limit: 0 } }
        end

        it { is_expected.to be_a_failure }
      end
    end
  end
end
