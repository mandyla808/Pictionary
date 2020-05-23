module Main exposing (..)

--Imports--
import Browser
import Browser.Events
import Html exposing (Html, div)
import Html.Events exposing (onClick, onInput)
import Html.Attributes exposing(placeholder, value)
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
import Canvas.Settings
import Html.Events.Extra.Mouse as Mouse

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

initPlayer : Int -> Player
initPlayer n =
  { name = ""
  , identity = n
  , score = 0
  , currentGuess = ""
  , guesses = []
  , isGuessing = False
  , isDrawing = False
  , isNamed = False
  }

initModel : Model
initModel =
  { players = []
  , numPlayers = 0
  , currentWord = Nothing
  , unusedWords = wordList
  , whiteboardClean = True
  , currentDrawer = Nothing
  , roundNumber = 0
  , roundTime = 60
  , gameTime = 0
  , restStart = 0 -- restStart = 0?
  , roundPlaying = False -- Is the round still on?
  , segments = Array.empty
  , drawnSegments = []
  , tracer = Nothing
  , color = Color.black
  , size = 20.0
  , currentScreen = 0
  }

--SUBSCRIPTIONS
subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
  [ Time.every 1000 Tick
  , Browser.Events.onAnimationFrameDelta NextScreen
  ]

--UPDATE
update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    None ->
      (model, Cmd.none)
    Tick t ->
      ({model | roundTime = model.roundTime-1
                 , gameTime = model.gameTime + 1},
      if model.roundTime == 1 then toCmd RoundOver
      else if (model.gameTime - model.restStart == 5) then toCmd StartRound
      else Cmd.none)

    --Adds player when a button ("Click to join!") is hit
    NewPlayer ->
      ({model | numPlayers = model.numPlayers + 1
              , players = model.players ++ [(initPlayer model.numPlayers)]
              }, Cmd.none)

    UpdateName player newName ->
      let
        updatedPlayer = {player | name = newName}
      in
          ({model | players = (updatePlayer model.players updatedPlayer)}
          ,Cmd.none)

    --Player submits their name
    SubmitName player ->
      let
        updatedPlayer = {player | isNamed = True}
      in
        ({model | players = (updatePlayer model.players updatedPlayer)}
        ,Cmd.none)

    --Tracks what the player has in their text box
    UpdateCurrentGuess player guess ->
        let
          updatedPlayer = {player | currentGuess = guess}
        in
          ({model | players = (updatePlayer model.players updatedPlayer)}
          ,Cmd.none)

    NextScreen float ->
      (drawSegments model , Cmd.none)


    Guess player guess ->
      (playerGuessUpdate model player guess, Cmd.none)
    RoundOver ->
      (roundOverUpdate model, Cmd.none)
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
        Just x ->
          ((addSegment point x model) , Cmd.none)
        Nothing ->
          (model, Cmd.none)
    EndDraw point ->
      case model.tracer of
        Just x ->
          ((endSegment point x model) , Cmd.none)
        Nothing ->
          (model, Cmd.none)

stringView : List String -> List (Html Msg)
stringView xs =
  case xs of
    [] -> []
    x :: rest -> Html.text(x) :: (stringView rest)

--Takes a list of Html objects and puts them in an Html div
applyHtmlDiv : List (Html Msg) -> Html Msg
applyHtmlDiv xs = Html.div [] xs


--Views all info on a player
viewPlayerInfo : Player -> List (Html Msg)
viewPlayerInfo p =
  List.map applyHtmlDiv
    [ [Html.text("Name: " ++ p.name)]
    , [Html.text("Player ID: " ++ String.fromInt p.identity)]
    , [Html.text("Current Guess: " ++ p.currentGuess)]
    , [Html.text("Score: " ++ String.fromInt p.score)]
    , if p.isDrawing then [Html.text(p.name ++ " is drawing!")]
      else [Html.text("")]
    , stringView p.guesses]

--VIEW
view : Model -> Html Msg
view model =
  Html.div
    []
    [ Html.div
      []
      [Html.text ("Timer:" ++ String.fromInt model.roundTime)]

    , Html.div
      []
      [Html.button [onClick StartRound][Html.text "Start Round:"]
    , Html.text ( "Round num:" ++ String.fromInt model.roundNumber ++ "Current word:" ++
        case model.currentWord of
          Nothing -> "No word"
          Just w -> w)]

    , Html.div
      []
      [Html.button [onClick RoundOver][Html.text "End round"]
    , Html.text ("Game Time" ++ String.fromInt model.gameTime ++ "RestStart:" ++ String.fromInt model.restStart)]

--  Manually add players
    , Html.div
      []
      [Html.button [onClick NewPlayer] [Html.text "Click to add player"]]
    ,
      let
        printPlayers : List Player -> String
        printPlayers ps =
          case ps of
            [] -> ""
            p::rest -> p.name ++ ", " ++ printPlayers rest
        giveNameBoxes : List Player -> List (Html Msg)
        giveNameBoxes players =
          case players of
            [] -> []
            p :: rest ->
              (Html.input [placeholder ("Enter Name"), value p.name, onInput (UpdateName p)] []) ::
                giveNameBoxes rest
      in
        Html.div
        []
        (giveNameBoxes model.players)

-- Submit player names
    ,  let
        giveNameButton : List Player -> List (Html Msg)
        giveNameButton players =
          case players of
            [] -> []
            p :: rest ->
              if not p.isNamed then
                (Html.button [onClick (SubmitName p)]
                [Html.text ("Enter Name!")])
                  :: giveNameButton rest
              else
                giveNameButton rest
        in
          Html.div []
            (giveNameButton model.players)

--  ALLOWS PLAYERS TO TYPE IN GUESSES
    , Html.div
      []
      (let
        giveGuessBoxes : List Player -> List (Html Msg)
        giveGuessBoxes players =
          case players of
            [] -> []
            p :: rest ->
              (Html.input [placeholder ("Guess for " ++ String.fromInt (p.identity+1)),
                            value p.currentGuess, onInput (UpdateCurrentGuess p)] []) :: giveGuessBoxes rest
      in
        giveGuessBoxes model.players)

-- Allows players to submit guesses
    ,  let
        giveGuessButton : List Player -> List (Html Msg)
        giveGuessButton players =
          case players of
            [] -> []
            p :: rest ->
              if p.isGuessing then
                (Html.button [onClick (Guess p p.currentGuess)]
                [Html.text ("Submit guess player" ++ String.fromInt(p.identity +1))])
                  :: giveGuessButton rest
              else
                giveGuessButton rest
        in
          Html.div []
            (giveGuessButton model.players)

--View all player information
    , applyHtmlDiv (List.map applyHtmlDiv (List.map viewPlayerInfo model.players))

--Canvas
    , Canvas.toHtml (750, 750)
        [ Mouse.onDown (.offsetPos >> BeginDraw)
        , Mouse.onMove (.offsetPos >> ContDraw)
        , Mouse.onUp (.offsetPos >> EndDraw)
        ]
        ( ( Canvas.shapes [ Canvas.Settings.stroke Color.blue ] [ Canvas.rect ( 0, 0 ) 750 750 ]) ::
          model.drawnSegments )
    ]
