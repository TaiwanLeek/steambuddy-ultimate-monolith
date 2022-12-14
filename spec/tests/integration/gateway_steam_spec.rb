# frozen_string_literal: true

require_relative 'helpers/spec_helper'
require_relative '../require_app'
require_app

describe 'Tests Steam API library' do
  VCR.configure do |c|
    c.cassette_library_dir = CASSETTES_FOLDER
    c.hook_into :webmock

    c.filter_sensitive_data('<STEAM_ID>') { STEAM_ID }
    c.filter_sensitive_data('<STEAM_KEY>') { STEAM_KEY }
  end

  before do
    VCR.insert_cassette CASSETTE_FILE,
                        record: :new_episodes,
                        match_requests_on: %i[method uri headers]
  end

  after do
    VCR.eject_cassette
  end

  describe 'Friends information' do
    it 'should provide correct friend list' do
      player = SteamBuddy::Steam::PlayerMapper.new(STEAM_KEY)
        .find(STEAM_ID)
      player_friend_set = player.friend_list.map(&:steam_id)

      correct_friend_set = CORRECT['friends'].map do |friend|
        friend['steamid']
      end

      _(player_friend_set).must_equal correct_friend_set
    end
  end
  describe 'Owned games information' do
    it 'should provide correct game count' do
      player = SteamBuddy::Steam::PlayerMapper.new(STEAM_KEY)
        .find(STEAM_ID)
      correct_game_count = CORRECT['owned']['response']['game_count']
      if correct_game_count
        _(player.game_count).must_equal correct_game_count
      else
        assert_nil owned_games.count
      end
    end

    it 'should provide correct owned game list' do
      player = SteamBuddy::Steam::PlayerMapper.new(STEAM_KEY)
        .find(STEAM_ID)
      player_owned_games_set = player.played_games.map(&:appid)
      correct_games_set = CORRECT['owned']['response']['games'].map do |game|
        game['appid']
      end
      if correct_games_set
        _(player_owned_games_set).must_equal correct_games_set
      else
        assert_nil player_owned_games_set
      end
    end
  end
end
