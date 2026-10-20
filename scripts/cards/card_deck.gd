class_name CardDeck
extends RefCounted
## Draw pile / hand / discard with a seeded shuffle, so a given seed always deals the same
## sequence (repeatable tests and replays). Hand slots keep their position: playing a card
## discards it and refills that same slot from the draw pile, reshuffling the discard pile
## into the draw pile when it runs out.

var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []
var hand: Array[CardData] = []
var hand_size: int = 3
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(cards: Array[CardData], seed_value: int, slots: int) -> void:
    _rng.seed = seed_value
    hand_size = slots
    draw_pile = cards.duplicate()
    discard_pile.clear()
    hand.clear()
    _shuffle(draw_pile)
    for i in hand_size:
        hand.append(_draw())


func card_in_slot(slot: int) -> CardData:
    return hand[slot] if slot >= 0 and slot < hand.size() else null


## Moves the slot's card to the discard pile and refills the slot. Returns the played card.
func play_slot(slot: int) -> CardData:
    var card: CardData = card_in_slot(slot)
    if card == null:
        return null
    discard_pile.append(card)
    hand[slot] = null
    hand[slot] = _draw()
    return card


## Adds a card mid-run (altar reward) at a random position in the draw pile.
func add_card(card: CardData) -> void:
    draw_pile.insert(_rng.randi_range(0, draw_pile.size()), card)


func all_cards() -> Array[CardData]:
    var cards: Array[CardData] = []
    cards.append_array(draw_pile)
    cards.append_array(discard_pile)
    for card: CardData in hand:
        if card != null:
            cards.append(card)
    return cards


func total_cards() -> int:
    var in_hand: int = 0
    for card: CardData in hand:
        if card != null:
            in_hand += 1
    return draw_pile.size() + discard_pile.size() + in_hand


func _draw() -> CardData:
    if draw_pile.is_empty():
        draw_pile = discard_pile.duplicate()
        discard_pile.clear()
        _shuffle(draw_pile)
    return draw_pile.pop_back() if not draw_pile.is_empty() else null


## Fisher–Yates with the deck's own RNG (never the global one).
func _shuffle(cards: Array[CardData]) -> void:
    for i in range(cards.size() - 1, 0, -1):
        var j: int = _rng.randi_range(0, i)
        var tmp: CardData = cards[i]
        cards[i] = cards[j]
        cards[j] = tmp
