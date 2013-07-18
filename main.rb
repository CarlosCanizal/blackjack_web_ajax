require 'rubygems'
require 'sinatra'

set :sessions, true

helpers do

  def start_game
    suits = ["\u2660", "\u2665", "\u2666", "\u2663"]
    values = ["A","2","3","4","5","6","7","8","9","10","Q","K"]
    deck = suits.product(values)
    decks = [deck,deck,deck,deck]

  end

  def show_cards(hand)
    cards = []
    hand.each do |card|
      cards << card[0]+card[1]
    end
    cards.join(", ")
  end

  def close_game
    session[:player_name] = nil
    session[:player_label] = nil
    session[:bet] = nil
    session[:decks] = nil
    session[:money] = nil
    session[:user_hand] = nil
    session[:dealer_hand] = nil
    session[:end_game] = true
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

    until dealer_total > 16
      dealer_hand << hit_card
      dealer_total = hand_total(dealer_hand)
    end

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
    {result:result, money:money}
  end

end

get '/take_my_money' do
  redirect '/game' unless session[:end_game] == true
  close_game
  erb :take_my_money
end

get '/' do
  erb :index
end

get '/close_game' do
  close_game
  redirect "/"
end

post '/hit' do
  session[:user_hand] << hit_card
  @user_hand = session[:user_hand]
  @user_total = hand_total(@user_hand)
  if @user_total >=21
    result = results(session[:user_hand], session[:dealer_hand], session[:money], session[:bet])
    session[:result] = result[:result]
    session[:money] = result[:money]
    session[:end_game] = true
    redirect '/results' 
  end
  redirect '/game'
end

post '/stay' do
  session[:end_game] = true
  result = results(session[:user_hand], session[:dealer_hand], session[:money], session[:bet])
  session[:result] = result[:result]
  session[:money] = result[:money]
  redirect '/results'
end

get '/results' do
  redirect '/game' unless session[:end_game] == true
  session[:bet] = nil
  @player_name = session[:player_name]
  @player_label = session[:player_label]
  @money = session[:money]

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

  erb :results
end

get '/game' do
  redirect '/new_player?access=no_access' unless session[:player_name]
  redirect '/bet' unless session[:bet]
  @player_name = session[:player_name]
  @player_label = session[:player_label]
  @bet = session[:bet]
  @user_hand = session[:user_hand]
  @user_total = hand_total(@user_hand)
  @dealer_hand = session[:dealer_hand]
  erb :game
end

post '/game' do
    redirect '/new_player?access=no_access' unless session[:player_name]

    @bet = params["bet"].to_i
    
    redirect '/bet?bet=invalid' if @bet < 1
    redirect '/bet?bet=greater' if @bet > session[:money]

    session[:bet] = @bet
    session[:decks] = start_game
    session[:user_hand] = []
    session[:dealer_hand] = []
    session[:end_game] = false

    @player_name = session[:player_name]
    @player_label = session[:player_label]
    
    2.times { session[:user_hand] << hit_card }
    2.times { session[:dealer_hand] << hit_card }

    @user_hand = session[:user_hand]
    @user_total = hand_total(@user_hand)

    if @user_total == 21
      result = results(session[:user_hand], session[:dealer_hand], session[:money], session[:bet])
      session[:result] = result[:result]
      session[:money] = result[:money]
      session[:end_game] = true
      redirect '/results'
    end
    @dealer_hand = session[:dealer_hand]

    erb :game
end

get '/bet' do
  redirect '/new_player?access=no_access' unless session[:player_name]
  redirect '/back_to_game' unless session[:end_game]
  redirect '/close_game' if session[:money] < 1
  @error = "Please type a valid bet numeric greater than 0" if params["bet"] == "invalid"
  @error = "Your bet must be lower or equal than #{session[:money]}" if params["bet"] == "greater"
  @player_name = session[:player_name]
  @player_label = session[:player_label]
  @money = session[:money]
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
  session[:end_game] = true

  session[:money] = 500
  redirect '/bet'
end
