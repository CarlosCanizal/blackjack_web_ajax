function error_request(jqXHR){
	if (jqXHR.status == 401){
		window.location = "/new_player?access=no_access"
	}
	else if (jqXHR.status == 400){
		var errors  = jQuery.parseJSON(jqXHR.responseText)
		$('#error-message').html(errors.errors).show();
	}
	else{
		window.location = "/"
	}
}

$(document).ready(function(){


	$(document).on('click','.player-action',function(){
		var action = $(this).attr('action');
		var jqxhr = $.post('/game/'+action)
		.done(function(response) {
			if (response.game_action == 'player_turn'){
				$('#player-cards').append(response.user_card)
				$('#player-total').html(response.user_total)
			}
			else if ( response.game_action == 'player_busted'){
				$('#player-cards').append(response.user_card);
				$('#player-total').html(response.user_total);
				$('#hidden-card').replaceWith(response.dealer_card);
				$('#dealer-total').html(response.dealer_total);
				$('#bet-section').html(response.message);
				$('#player-money').html(response.money);
			}
			else if (response.game_action == 'dealer_turn'){
				$('#players-actions').html(response.message)
				$('#hidden-card').replaceWith(response.dealer_card)
				$('#dealer-total').html(response.dealer_total);
				if (action == 'hit'){
					$('#player-cards').append(response.user_card);
					$('#player-total').html(response.user_total);
					$('#player-money').html(response.money);
				}
			}
			else if (response.game_action == 'results'){
				$('#bet-section').html(response.message)
				$('#hidden-card').replaceWith(response.dealer_card)
				$('#dealer-total').html(response.dealer_total);
				$('#player-money').html(response.money);
			}
		})
		.fail(function(jqXHR, textStatus, errorThrown) { 
			 error_request(jqXHR);
		});
	});

	$(document).on('click','#dealer-card',function(){
		var jqxhr = $.post('/game/hit_dealer')
		.done(function(response) {
			$('#dealer-cards').append(response.dealer_card)
			$('#dealer-total').html(response.dealer_total)
			if (response.game_action == 'results'){
				$('#bet-section').html(response.message);
				$('#player-money').html(response.money)
			}
		})
		.fail(function(jqXHR, textStatus, errorThrown) { 
			 error_request(jqXHR);
		});
	});

	$(document).on('click','#take-my-money',function(){
		var jqxhr = $.post('/game/results/take_my_money')
		.done(function(response) {
			$('#casino').html(response);
		})
		.fail(function(jqXHR, textStatus, errorThrown) { 
			 error_request(jqXHR);
		});
	});

	$(document).on('click','#play-again',function(){
		var jqxhr = $.post('/game/bet')
		.done(function(response){
			$('#casino').replaceWith(response);
		})
		.fail(function(jqXHR, textStatus, errorThrown) { 
			 error_request(jqXHR);
		});
	});

	$(document).on('submit','#make-a-bet',function(event){
		event.preventDefault();
		var jqxhr = $.post('/game',$(this).serialize())
		.done(function(response){
			$('#error-message').hide();
			$('#casino').replaceWith(response);
		})
		.fail(function(jqXHR, textStatus, errorThrown) {
			error_request(jqXHR);
		});
	});

});