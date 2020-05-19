module Main exposing (..)

--Imports--
import Browser
import Html exposing (Html)
import Html.Events exposing (onClick)
import Debug
import Random
import Time exposing (Posix)
import Random.List
import Task.Extra exposing (message)
import System.Message exposing (toCmd)

import Types exposing(..)
import Updates exposing (..)
import Words exposing (..)

import Array exposing (Array)
import Color exposing (Color)
import Canvas

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
  , roundNumber = 0
  , roundTime = 60
  , gameTime = 0
  , restStart = 0
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
    None ->
      (model, Cmd.none)
    Tick t ->
      let
        newModel = drawSegments model
      in
      ({newModel | roundTime = model.roundTime-1
                 , gameTime = model.gameTime + 1},
      if model.roundTime == 1 then toCmd RoundOver
        else Cmd.none)
    Guess player guess ->
      (playerUpdate model player guess, Cmd.none)
    RoundOver ->
      (roundOverUpdate model, toCmd RestPeriod)
    RestPeriod ->
      ({model | restSeconds = 1 + model.restSeconds },
      if (model.gameTime - model.restStart == 5) then toCmd StartRound
      else toCmd RestPeriod)
    NewWord (newWord, words) ->
      (newWordUpdate model newWord words, Cmd.none)
    NewDrawer (drawer, _) ->
      (newDrawerUpdate model drawer, Cmd.none)
    StartRound ->
      (startRoundUpdate model, Cmd.batch[
        Random.generate NewWord (Random.List.choose model.unusedWords),
        Random.generate NewDrawer (Random.List.choose model.players)
        ])
    BeginDraw point ->
      ({model | tracer = Just {prevMidpoint = point , lastPoint = point} }
      , Cmd.none)
    ContDraw point ->
      case model.tracer of
        Just _ ->
          ((addSegment p model.tracer model) , Cmd.none)
        Nothing ->
          (model, Cmd.none)
    EndDraw point ->
      case model.tracer of
        Just _ ->
          ((endSegment p model.tracer model) , Cmd.none)
        Nothing ->
          (model, Cmd.none)

--VIEW
view : Model -> Html Msg
view model =
  Html.div
    []
    [ Html.text ("Timer:" ++ String.fromInt model.roundTime)
    , Html.button [onClick StartRound][Html.text "Start Round:"]
    , Html.text ( "Round num:" ++ String.fromInt model.roundNumber ++ "Current word:" ++
        case model.currentWord of
          Nothing -> "No word"
          Just w -> w)
    , Html.button [onClick RoundOver][Html.text "End round"]
    , Html.text ("Game Time" ++ String.fromInt model.gameTime ++ "RestStart:" ++ String.fromInt model.restStart)
    , Canvas.toHtml (750, 750)
        [ Mouse.onDown (.offsetPos >> StartAt)
        , Mouse.onMove (.offsetPos >> MoveAt)
        , Mouse.onUp (.offsetPos >> EndAt)
        ]
        model.drawnSegments
    ]
