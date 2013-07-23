require 'rubygems'
require 'sinatra'
require 'json'

set :sessions, true

helpers do

  def start_game
    suits = ["clubs", "diamonds", "hearts", "spades"]
    values = ["A","2","3","4","5","6","7","8","9","10","Q","K"]
    deck = suits.product(values)
    decks = [deck,deck,deck,deck]
  end

  def show_cards(hand)
    cards = ""
    hand.each do |card|
      cards += "<img class='card' alt='#{card[0]}_#{card[1]}' src='/images/cards/#{card[0]}_#{card[1]}.jpg' />"
    end
    cards
  end

  def close_game
    restart_game
    session[:player_name] = nil
    session[:player_label] = nil
    session[:money] = nil
  end

  def restart_game
    session[:bet] = nil
    session[:decks] = nil
    session[:user_hand] = nil
    session[:dealer_hand] = nil
    session[:game_step] = nil
  end

  def hit_card
    @decks = session[:decks]
    rand_deck = rand(@decks.length)
    rand_card = rand(@decks[rand_deck].length)
    card = @decks[rand_deck][rand_card]
    @decks[rand_deck].delete_at(rand_card)
  end

  def hand_total(hand)
    values = {"A"=>11,"2"=>2,"3"=>3,"4"=>4,"5"=>5,"6"=>6,"7"=>7,"8"=>8,"9"=>9,"10"=>10,"J"=>10,"Q"=>10,"K"=>10}
    hand_total = 0 
    aces = []
    hand.each do |card|
      card[1]
      if card[1] == "A"
        aces << card
      else
        hand_total += values[card[1]]
      end
    end

    aces.each do |card|
      hand_total += hand_total+values[card[1]] > 21 ? 1 : values[card[1]]
    end
    hand_total
  end

  def result_message(message, money, bet)
    buttons = "<a id='play-again' class='btn btn-large btn-info'>Play Again</a>
               <a id='take-my-money' class='btn btn-large btn-warning'>Take my money</a>"

    if money < 1
      buttons = "<h3>You don't have any money left, please Go Out!</h3>
                 <a href='close_game' id='go-out' class='btn btn-large btn-danger'>Go Out</a>"
    end
    message = case session[:result]
      when "lose" then "<h2>Sorry #{@player_label} #{@player_name} You Lose $#{bet}</h2> #{buttons}"
      when "win" then "<h2>Congratulations! #{@player_label} #{@player_name} You Win $#{bet}</h2>  #{buttons}"
      when "draw" then "<h2>This is a Draw</h2> #{buttons}"
      when "blackjack" then "<h2>Blackjack! #{@player_label} #{@player_name} You Win $#{bet}</h2> #{buttons}"
    end
  end

  def results(user_hand, dealer_hand, money, bet)

    user_total = hand_total(user_hand)
    dealer_total = hand_total(dealer_hand)

    if user_total > 21
      result = "lose"
      money -= bet
    else

      if user_total == dealer_total
        result = "draw"
      else
        if user_total == 21 && user_hand.length == 2
          result = "blackjack"
          bet *= 1.5
          money += bet
        else
          if user_total > dealer_total || dealer_total > 21
            result = "win"
            money += bet
          else
            result = "lose"
            money -= bet
          end
        end
      end
    end
    puts session[:game_step]
    unless session[:game_step] == nil
      session[:game_step] = nil
      session[:result] = result
      session[:money] = money
      session[:bet] = bet
    end
    {result:result, money:money}
  end

end

before '/game' do
  redirect '/new_player?access=no_access' unless session[:player_name]
  @player_name = session[:player_name]
  @player_label = session[:player_label]
  @dealer_total = '?'
  @show_cards = false
  @results = false
  @message = nil
  @money = session[:money]
end

before '/game/*' do
  unless session[:player_name]
    close_game
    halt 401, "Not authorized"
  end
  @player_name = session[:player_name]
  @player_label = session[:player_label]
  @money = session[:money]
end

before '/game/results/*' do
  halt 401, "Not authorized" if session[:game_step] == :playing
  @player_name = session[:player_name]
  @player_label = session[:player_label]
  @money = session[:money]
end

before '/new_player' do
  redirect '/back_to_game' if session[:game_step]
end

get '/' do
  erb :index
end

get '/close_game' do
  close_game
  redirect "/"
end

post '/game/results/take_my_money' do
  @money = session[:money]
  close_game
  erb :take_my_money, :layout=>false
end

post '/game/hit' do
  content_type :json
  @user_card = hit_card
  session[:user_hand] << @user_card
  @user_hand = session[:user_hand]
  @user_total = hand_total(@user_hand)
  @dealer_card = nil
  @dealer_total = nil
  @message = nil
  if @user_total >21
    @dealer_hand = session[:dealer_hand]
    @dealer_total = hand_total(@dealer_hand)
    result = results(session[:user_hand], session[:dealer_hand], session[:money], session[:bet])
    @dealer_card = show_cards([@dealer_hand[1]])
    @game_action = 'player_busted'
    @message = result_message(result[:result],session[:money], session[:bet])
  elsif @user_total == 21
    @dealer_hand = session[:dealer_hand]
    @dealer_total = hand_total(@dealer_hand)
    session[:game_step] = :dealer_turn
    @dealer_card = show_cards([@dealer_hand[1]])
    @game_action = 'dealer_turn'
    @message = "<a id='dealer-card' class='btn btn-large btn-info'>See next dealer card?</a>"
  else
    @game_action = 'player_turn'
  end
  { user_card:show_cards([@user_card]), 
    user_total:@user_total, 
    dealer_card:@dealer_card,
    dealer_total:@dealer_total,
    game_action:@game_action,
    message:@message,
    money:session[:money]
  }.to_json
end

post '/game/stay' do
  content_type :json
  session[:game_step] = :dealer_turn
  @dealer_hand = session[:dealer_hand]
  @dealer_card = show_cards([@dealer_hand[1]])
  @dealer_total = hand_total(@dealer_hand)
  @message = "<a id='dealer-card' class='btn btn-large btn-info'>See next dealer card?</a>"
  @game_action = 'dealer_turn'
  if @dealer_total > 16
    result =results(session[:user_hand], session[:dealer_hand], session[:money], session[:bet])
    @message = result_message(result[:result],session[:money], session[:bet])
    @game_action = 'results'
  end

  { 
    game_action:@game_action,
    dealer_card:@dealer_card,
    dealer_total:@dealer_total,
    message: @message,
    money:session[:money]
  }.to_json
end

post '/game/hit_dealer' do
  content_type :json
  @dealer_card = hit_card
  session[:dealer_hand] << @dealer_card
  @dealer_hand = session[:dealer_hand]
  @dealer_total = hand_total(@dealer_hand)
  @message = nil
  @game_action = 'dealer_turn'
  if @dealer_total >16
    result =results(session[:user_hand], session[:dealer_hand], session[:money], session[:bet])
    @message = result_message(result[:result],session[:money], session[:bet])
    @game_action = 'results'
  end
  session[:game_step] = :dealer_turn
  { dealer_card:show_cards([@dealer_card]),
    dealer_total:@dealer_total,
    game_action:@game_action,
    message:@message,
    money:session[:money]
  }.to_json
end

get '/game' do
  if session[:money] < 1
    close_game
    redirect '/' 
  end
  if session[:bet]
    @dealer_turn = false
    @bet = session[:bet]
    @user_hand = session[:user_hand]
    @user_total = hand_total(@user_hand)
    @dealer_hand = session[:dealer_hand]
    if session[:game_step] == :dealer_turn
      @dealer_turn = true 
      @dealer_total = hand_total(@dealer_hand)
      @show_cards = true
      if @dealer_total >16
        @results = true
        result =results(session[:user_hand], session[:dealer_hand], session[:money], session[:bet])
        @message = result_message(result[:message], session[:money], session[:bet])
      end
    elsif session[:game_step] == nil
      @dealer_total = hand_total(@dealer_hand)
      @show_cards = true
      @results = true
      result =results(session[:user_hand], session[:dealer_hand], session[:money], session[:bet])
      @message = result_message(result[:message], session[:money], session[:bet])
    end
    erb :game
  else
    erb :bet
  end
end

post '/game' do

    unless session[:player_name]
      status 401
    else
      @bet = params["bet"].to_i
      session[:bet] = @bet
      redirect '/game' if session[:user_hand]
      if @bet < 1 || @bet > session[:money]

        session[:bet] = nil
        @error = "Please type a valid bet numeric greater than 0" if @bet < 1
        @error = "Your bet must be lower or equal than #{session[:money]}" if @bet > session[:money]
        
        content_type :json
        body({errors:@error}.to_json)
        status 400
      else
        session[:game_step] = :playing
        
        session[:decks] = start_game
        session[:user_hand] = []
        session[:dealer_hand] = []
        
        2.times { session[:user_hand] << hit_card }
        2.times { session[:dealer_hand] << hit_card }

        @user_hand = session[:user_hand]
        @user_total = hand_total(@user_hand)

        if @user_total == 21
          @show_cards = true
          @dealer_hand = session[:dealer_hand]
          @dealer_total = hand_total(@dealer_hand)
          if @dealer_total > 16
            @results = true
            result =results(session[:user_hand], session[:dealer_hand], session[:money], session[:bet])
            @message = result_message(result[:message], session[:money], session[:bet])
          end
        end
        @dealer_hand = session[:dealer_hand]

        erb :game, :layout=>false
      end
    end
end

post '/game/bet' do
  halt 401, "Not authorized" if session[:game_step] == :playing
  halt 401, "Not authorized" if session[:money] < 1
  restart_game
  erb :bet, :layout=>false
end

get '/new_player' do
  redirect '/back_to_game' if session[:player_name]
  @error = "Sorry, You have no acccess to the CASINO. Please register!" if params["access"] == "no_access"
  @error = "Please let me know your name" if params["name"] == "empty"
  @error = "Please select a valid label" if params["label"] == "invalid"
  erb :new_player
end

get '/back_to_game' do
  erb :back_to_game
end

post '/new_player' do
  labels = ['Mrs.', 'Miss', 'Mr.']
  player_name = params["player_name"].capitalize
  player_label = params["player_label"]

  redirect "/new_player?label=invalid" unless labels.include? player_label
  redirect "/new_player?name=empty" if player_name.empty?
  
  session[:player_name] = player_name
  session[:player_label] = player_label
  session[:game_step] = :bet
  session[:money] = 500
  redirect '/game'
end
