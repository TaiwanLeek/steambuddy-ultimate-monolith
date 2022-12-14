# frozen_string_literal: true

require 'roda'
require 'slim'
require 'slim/include'

module SteamBuddy
  # Web App
  class App < Roda
    plugin :halt
    plugin :flash
    # plugin :all_verbs # allows HTTP verbs beyond GET/POST (e.g., DELETE)
    plugin :render, engine: 'slim', views: 'app/presentation/views_html'
    plugin :public, root: 'app/presentation/public'
    plugin :assets, path: 'app/presentation/assets',
                    css: 'style.css', js: 'table_row.js'
    plugin :common_logger, $stderr

    # use Rack::MethodOverride # allows HTTP verbs beyond GET/POST (e.g., DELETE)

    route do |routing| # rubocop:disable Metrics/BlockLength
      routing.assets # load CSS
      response['Content-Type'] = 'text/html; charset=utf-8'
      routing.public

      # GET /
      routing.root do
        session[:watching] ||= []

        result = Service::ListPlayers.new.call

        if result.failure?
          flash[:error] = result.failure
          viewable_players = []
        else
          players = result.value!
          flash.now[:notice] = 'Add a Steam ID to get started' if players.none?

          viewable_players = Views::PlayersList.new(players).filter(session[:watching])
        end

        view 'home', locals: { players: viewable_players }
      end

      routing.on 'player' do # rubocop:disable Metrics/BlockLength
        routing.is do
          # POST /player/
          routing.post do
            id_request = Forms::NewPlayer.new.call(routing.params) #  output: <Dry::Validation::Result:0x00007f4658035db8>
            player_made = Service::AddPlayer.new.call(id_request)

            if player_made.failure?
              flash[:error] = player_made.failure
              routing.redirect '/'
            end

            player = player_made.value!

            # Add player and player's friends remote_id to session
            session[:watching].insert(0, player.remote_id).uniq!
            flash[:notice] = 'player added to your list!'
            player&.friend_list&.each { |friend| session[:watching].insert(0, friend.remote_id).uniq! }

            # Redirect viewer to player page
            routing.redirect "player/#{player.remote_id}"
          end
        end

        routing.on String, String do |remote_id, info_value|
          # GET /player/remote_id/info_value
          routing.get do
            player_result = Service::GetTable.new.call(
              remote_id:,
              info_value:
            )

            player = player_result.value!
            puts 'player: '
            puts player
            viewable_player = Views::Player.new(player)

            # Show viewer the player
            view 'player', locals: { player: viewable_player, info_value: }
          end
        end

        # This route has to be placed AFTER |remote_id, info_value|
        routing.on String do |remote_id|
          # GET /player/remote_id
          routing.get { routing.redirect "#{remote_id}/game_count" }
        end
      end
    end
  end
end
