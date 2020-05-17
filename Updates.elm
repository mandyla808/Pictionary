module Updates exposing (..)

--Imports--
import Browser
import Html exposing (Html)
import Debug
import Types exposing (..)
import Random exposing (Generator)
import Random.List
--updatePlayer
--Inputs: players player
--Will search through the list of players
--If there is a player in the model's list with the same name, then they will be replaced with the input player field
updatePlayer : List Player -> Player -> List Player
updatePlayer players player =
  case players of
    [] -> []
    p :: rest ->
      if p.name == player.name then
        player :: rest
      else
        p :: (updatePlayer rest player)

--playerUpdate
--Inputs: model player guess
--Updates the player's list of guesses
--Updates the score of the player if they are correct, and prevents them from guessing in the round again
playerUpdate : Model -> Player -> String -> Model
playerUpdate model player guess =
  case model.currentWord of
    Nothing -> model
    Just cw ->
      let
        updatedGuesses =  guess :: player.guesses
      in
        if guess == cw then
          let
            updatedPlayer =
              {player |  score = (player.score + 1),
                         guesses = updatedGuesses,
                         isGuessing = False
              }
          in
            {model | players = (updatePlayer model.players updatedPlayer) }
        else
          let
            updatedPlayer = {player | guesses = updatedGuesses}
          in
            {model | players = (updatePlayer model.players updatedPlayer)}

--Updates the model when the round is over
--Makes all players unable to guess
--Stops the drawer from drawing
--Resets all the player's list of guesses
roundOverUpdate: Model -> Model
roundOverUpdate model =
  let
    playerRoundReset : Player -> Player
    playerRoundReset p = {p | isGuessing = False, isDrawing = False, guesses = []}
  in
    {model | currentWord = Nothing,
             currentDrawer = Nothing,
             roundPlaying = False,
             players = List.map playerRoundReset model.players
            }


newWordUpdate : Model -> Maybe String -> List String -> Model
newWordUpdate model cw ws =
  {model | currentWord = cw,
           unusedWords = ws
            }

newDrawerUpdate : Model -> Maybe Player -> Model
newDrawerUpdate model player =
  case player of
    Nothing -> model
    Just _ -> {model | currentDrawer = player}
