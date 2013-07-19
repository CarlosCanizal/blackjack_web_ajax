require 'rubygems'
require 'sinatra'

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
    session[:player_name] = nil
    session[:player_label] = nil
    session[:bet] = nil
    session[:decks] = nil
    session[:money] = nil
    session[:user_hand] = nil
    session[:dealer_hand] = nil
    session[:game_step] = nil
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
          money += (bet*1.5)
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
    session[:result] = result
    session[:money] = money
    {result:result, money:money}
  end

end

before '/game/*' do
  unless session[:player_name]
    close_game
    redirect '/new_player?access=no_access'
  end
  @player_name = session[:player_name]
  @player_label = session[:player_label]
  @money = session[:money]

end

before '/game/results/*' do
  redirect '/game' if session[:game_step] == :playing
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

get '/game/results/take_my_money' do
  @money = session[:money]
  close_game
  erb :take_my_money
end

post '/game/hit' do
  session[:user_hand] << hit_card
  @user_hand = session[:user_hand]
  @user_total = hand_total(@user_hand)
  if @user_total >21
    result = results(session[:user_hand], session[:dealer_hand], session[:money], session[:bet])
    session[:game_step] = nil
    redirect '/game/results/results'
  elsif @user_total == 21
    session[:game_step] = :dealer_turn
  end
  redirect '/game'
end

post '/game/stay' do
  session[:game_step] = :dealer_turn
  redirect '/game'
end

get '/game/results/results' do
  session[:bet] = nil
  @user_hand = session[:user_hand]
  @user_total = hand_total(session[:user_hand])

  @dealer_hand = session[:dealer_hand]
  @dealer_total = hand_total(@dealer_hand)
  
  @message = case session[:result]
    when "lose" then "Sorry #{@player_label} #{@player_name} You Lose #{@bet}"
    when "win" then "Congratulations! #{@player_label} #{@player_name} You Win #{@bet}"
    when "draw" then "This is a Draw"
    when "blackjack" then "#{@player_label} #{@player_name} You Win #{@bet}"
  end

  session[:user_hand] = nil
  session[:dealer_hand] = nil

  erb :results
end

post '/game/hit_dealer' do
  session[:dealer_hand] << hit_card
  @dealer_hand = session[:dealer_hand]
  @dealer_total = hand_total(@dealer_hand)
  if @dealer_total >16
    result =results(session[:user_hand], session[:dealer_hand], session[:money], session[:bet])
    session[:game_step] = nil
    redirect '/game/results/results'
  end
  session[:game_step] = :dealer_turn
  redirect '/game'
end

get '/game' do
  puts session[:game_step]
  redirect '/game/bet' unless session[:bet] 
  @dealer_turn = false
  @player_name = session[:player_name]
  @player_label = session[:player_label]
  @bet = session[:bet]
  @user_hand = session[:user_hand]
  @user_total = hand_total(@user_hand)
  @dealer_hand = session[:dealer_hand]
  puts session[:game_step]
  if session[:game_step] == :dealer_turn
    @dealer_turn = true 
    @dealer_total = hand_total(@dealer_hand)
    result =results(session[:user_hand], session[:dealer_hand], session[:money], session[:bet])
    session[:game_step] = nil
    redirect '/game/results/results' if @dealer_total >16
  end
  erb :game
end

post '/game' do
    @bet = params["bet"].to_i
    session[:bet] = @bet
    redirect '/game' if session[:user_hand]
    redirect '/game/bet?bet=invalid' if @bet < 1
    redirect '/game/bet?bet=greater' if @bet > session[:money]
    session[:game_step] = :playing
    
    session[:decks] = start_game
    session[:user_hand] = []
    session[:dealer_hand] = []

    @player_name = session[:player_name]
    @player_label = session[:player_label]
    
    2.times { session[:user_hand] << hit_card }
    2.times { session[:dealer_hand] << hit_card }

    @user_hand = session[:user_hand]
    @user_total = hand_total(@user_hand)

    if @user_total == 21
      session[:game_step] = :dealer_turn
      redirect '/game'
    end
    @dealer_hand = session[:dealer_hand]

    erb :game
end

get '/game/bet' do
  redirect '/game' if session[:game_step] == :playing
  redirect '/close_game' if session[:money] < 1
  @error = "Please type a valid bet numeric greater than 0" if params["bet"] == "invalid"
  @error = "Your bet must be lower or equal than #{session[:money]}" if params["bet"] == "greater"
  erb :bet
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
  redirect '/game/bet'
end
