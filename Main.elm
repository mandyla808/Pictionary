module Main exposing (..)

--Imports--
import Browser
import Html exposing (Html)
import Debug
import Random
import Time exposing (Posix)
import Random.List
import Task.Extra exposing (message)

import Types exposing(..)
import Updates exposing (..)
import Words exposing (..)

----------------------------------------------------------------------
main : Program Flags Model Msg
main =
  Browser.element
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }

--INITIALIZATION
init : Flags -> (Model, Cmd Msg)
init () =
  (initModel, Cmd.none)

initModel : Model
initModel =
  { players = []
  , currentWord = Nothing
  , unusedWords = wordList
  , whiteboardClean = True
  , currentDrawer = Nothing
  , roundNumber = 1
  , roundTime = 60
  , roundPlaying = False -- Is the round still on?
  , segments = Array.empty
  , drawnSegments = []
  , tracer = Nothing
  , color = Color.black
  , size = 20
  }

--SUBSCRIPTIONS
subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
  [ Time.every 1000 Tick
  ]

--UPDATE
update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    None -> (model, Cmd.none)
    Tick t -> ({model | roundTime = model.roundTime-1},
      if model.roundTime == 1 then message RoundOver
        else (drawSegments model))
    Guess player guess -> (playerUpdate model player guess, Cmd.none)
    RoundOver -> (roundOverUpdate model, Cmd.none)
    NextRound -> (model, Cmd.batch[
     Random.generate NewWord (Random.List.choose model.unusedWords),
     Random.generate NewDrawer (Random.List.choose model.players)
     ])
    NewWord (newWord, words) -> (newWordUpdate model newWord words, Cmd.none)
    NewDrawer (drawer, _) -> (newDrawerUpdate model drawer, Cmd.none)

drawSegments : 

--VIEW
view : Model -> Html Msg
view model =
  Html.div
    []
    [ Html.text ("Timer:" ++ String.fromInt model.roundTime)
    ]
