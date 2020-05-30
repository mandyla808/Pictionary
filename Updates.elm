module Updates exposing (..)

--Imports--
import Browser
import Html exposing (Html)
import Debug
import Types exposing (..)
import Random exposing (Generator)
import Random.List
import Array
import Canvas
import Canvas.Settings.Line as Line
import Canvas.Settings
import Color
--updatePlayer
--Inputs: players player
--Will search through the list of players
--If there is a player in the model's list with the same name, then they will be replaced with the input player field
updatePlayer : List Player -> Player -> List Player
updatePlayer players player =
  case players of
    [] -> []
    p :: rest ->
      if p.identity == player.identity then
        player :: rest
      else
        p :: (updatePlayer rest player)

--playerUpdate
--Inputs: model player guess
--Updates the player's list of guesses
--Updates the score of the player if they are correct, and prevents them from guessing in the round again
playerGuessUpdate : Model -> Player -> String -> Model
playerGuessUpdate model player guess =
  case model.currentWord of
    Nothing -> model
    Just cw ->
      let
        updatedGuesses =  guess :: player.guesses
      in
        if guess == cw then
          let
            updatedPlayer =
              {player |  score = (player.score + 1)
                       , guesses = updatedGuesses
                       , isGuessing = False
                       , currentGuess = ""
                       , isCorrect = True
              }
          in
            {model | players = (updatePlayer model.players updatedPlayer) }
        else
          let
            updatedPlayer = {player | guesses = updatedGuesses
                                    , currentGuess = ""}
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
    playerRoundReset p = {p | isGuessing = False, isDrawing = False, isCorrect = False, guesses = []}
    newModel = drawSegments model
  in
    {newModel | currentWord = Nothing,
             currentDrawer = Nothing,
             roundPlaying = False,
             players = List.map playerRoundReset model.players,
             roundTime = 0,
             restStart = model.gameTime,
             segments = Array.empty,
             drawnSegments = [],
             tracer = Nothing,
             color = Color.black,
             size = 20.0
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
    Just p  ->
      let
        updatedPlayer = {p | isDrawing = True
                            ,isCorrect = True}
      in
        {model | currentDrawer = player
               , players = updatePlayer model.players updatedPlayer}

--Changes isGuessing status to true
allowGuess : Player -> Player
allowGuess p =
  if not p.isDrawing then
    {p | isGuessing = True}
  else
    p

startRoundUpdate : Model -> Model
startRoundUpdate model =
  {model | roundNumber = model.roundNumber + 1
         , roundPlaying = True
         , roundTime = 60
         , players = List.map allowGuess model.players
         , segments = Array.empty
         , drawnSegments = []
         , tracer = Nothing
       }

--After every tick, draw the segments
--set segments to empty array
drawSegments : Model -> Model
drawSegments model =
  if model.roundPlaying
    then {model | drawnSegments = Array.toList model.segments
         , segments = Array.empty
         , currentScreen = model.currentScreen + 1 }
  else { model
       | drawnSegments = [ Canvas.shapes [ Canvas.Settings.fill Color.white ]
                                         [ Canvas.rect ( 1, 1 ) 748.0 748.0 ]]
       , currentScreen = model.currentScreen + 1 }

receiveTracer : List (Float) -> Model -> Model
receiveTracer l model =
    case l of
      x1 :: y1 :: x2 :: y2 :: z1 :: z2 :: n :: [] ->
        let
          p1 = (x1, y1)
          p2 = (x2, y2)
          t = { prevMidpoint = p1 , lastPoint = p2 }
          p = (z1, z2)
          newModel = (
            if n < 2.0  -- same as n == 1.0
              then addSegment p t model
            else if n > 1.0 -- same as n == 2.0
              then endSegment p t model
            else { model | tracer = Just { prevMidpoint = p1 , lastPoint = p2 }})
        in
          newModel
      _ ->  -- error
        { model | tracer = Nothing }

addSegment :  Canvas.Point -> Trace -> Model -> Model
addSegment p t model =
  let
    newPoint =
      case (p, t.lastPoint) of
        ((p_x, p_y), (t_x, t_y)) ->
          (t_x + (p_x - t_x) / 2 , t_y + (p_y - t_y) / 2)
  in
    { model | tracer = Just { prevMidpoint = newPoint , lastPoint = p }
            , segments = (Array.push
              (Canvas.shapes
                [ Line.lineWidth model.size
                , Line.lineCap Line.RoundCap
                , Line.lineJoin Line.RoundJoin
                , Canvas.Settings.stroke model.color]
                [Canvas.path t.prevMidpoint [Canvas.quadraticCurveTo t.lastPoint newPoint] ]
              ) model.segments)
    }

endSegment :  Canvas.Point -> Trace -> Model -> Model
endSegment p t model =
    { model | tracer = Nothing
            , segments = (Array.push
              (Canvas.shapes
                [ Line.lineWidth model.size
                , Line.lineCap Line.RoundCap
                , Line.lineJoin Line.RoundJoin
                , Canvas.Settings.stroke model.color]
                [Canvas.path t.prevMidpoint [Canvas.quadraticCurveTo t.lastPoint p] ]
              ) model.segments)
    }
