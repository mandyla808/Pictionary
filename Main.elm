port module Main exposing (..)

--Imports--
import Browser
import Browser.Events
import Html exposing (Html, div)
import Html.Events exposing (onClick, onInput)
import Html.Attributes exposing(placeholder, value, style)
import Debug
import Random
import Time exposing (Posix)
import Random.List
import Task.Extra exposing (message)
import System.Message exposing (toCmd)

import Json.Decode as D
import Json.Encode as E

import Types exposing(..)
import Updates exposing (..)
import Words exposing (..)

import Array exposing (Array)
import Color exposing (Color)
import Canvas
import Canvas.Settings
import Canvas.Settings.Line as Line
import Html.Events.Extra.Mouse as Mouse
import Tuple exposing (first,second)

import Element
import Element.Input
import Element.Background
import Element.Border

----------------------------------------------------------------------
-- Ports
port infoForJS : GenericOutsideData -> Cmd msg
port infoForElm : (GenericOutsideData -> msg) -> Sub msg

port firebaseWrite : String -> Cmd msg
port firebaseRead : (String -> msg) -> Sub msg


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
  , username = n
  , score = 0
  , currentGuess = ""
  , isGuessing = False
  , isDrawing = False
  , isNamed = False
  , isCorrect = False
  }

initModel : Model
initModel =
  { players = []
  , numPlayers = 0
  , currentWord = Nothing
  , unusedWords = wordList
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
  , size = 20.0
  , currentScreen = 0

  , username = -1
  }

--SUBSCRIPTIONS
subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
  [ Time.every 1000 Tick
  , Browser.Events.onAnimationFrameDelta NextScreen
  , infoForElm ReceiveValue
  ]

--UPDATE
update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    None ->
      (model, Cmd.none)

    ReceiveValue outsideInfo ->
      case outsideInfo.tag of
        "sharedModel/tracer" ->
          if model.username /= 1 then
            case D.decodeValue (D.list D.float) outsideInfo.data of
              Err _ -> (model, Cmd.none)
              Ok l ->
                ( (receiveTracer l model)
                , Cmd.none
                )
          else (model, Cmd.none)

        "sharedModel/roundTime" ->
          case D.decodeValue D.int outsideInfo.data of
            Err _ -> (model, Cmd.none)
            Ok n ->
              ( { model | roundTime = n}
              , Cmd.none
              )

        "sharedModel/gameTime" ->
          case D.decodeValue D.int outsideInfo.data of
            Err _ -> (model, Cmd.none)
            Ok n ->
              ( {model | gameTime = n}
              , Cmd.none
              )

        "sharedModel/restStart" ->
          case D.decodeValue D.int outsideInfo.data of
            Err _ -> (model, Cmd.none)
            Ok n ->
              ( {model | restStart = n}
              , Cmd.none
              )

        "sharedModel/numPlayers" ->
          case D.decodeValue D.int outsideInfo.data of
            Err _ -> (model, Cmd.none)
            Ok n ->
              ( (if model.username == -1
                  then {model | numPlayers = n, username = n}
                  else {model | numPlayers = n})
              , Cmd.none
              )

        "sharedModel/roundNumber" ->
          case D.decodeValue D.int outsideInfo.data of
            Err _ -> (model, Cmd.none)
            Ok n ->
              ( {model | roundNumber = n}
              , Cmd.none
              )

        "sharedModel/roundPlaying" ->
          case D.decodeValue D.bool outsideInfo.data of
            Err _ -> (model, Cmd.none)
            Ok b ->
              ( {model | roundPlaying = b}
              , Cmd.none
              )

        "sharedModel/currentWord" ->
          case D.decodeValue D.string outsideInfo.data of
            Err _ -> (model, Cmd.none)
            Ok w ->
              case w of
                "NOWORD" ->
                  ( {model | currentWord = Nothing}
                  , Cmd.none)
                _ ->
                  ( {model | currentWord = Just w}
                  , Cmd.none)

        "sharedModel/unusedWords" ->
          case D.decodeValue (D.list D.string) outsideInfo.data of
            Err _ -> (model, Cmd.none)
            Ok ws ->
              ( {model | unusedWords = ws}
              , Cmd.none
              )

        "sharedModel/color" ->
          case D.decodeValue D.int outsideInfo.data of
            Err _ -> (model, Cmd.none)
            Ok n ->
              ( {model | color = receiveColor n}
              , Cmd.none
              )

        "sharedModel/size" ->
          case D.decodeValue D.float outsideInfo.data of
            Err _ -> (model, Cmd.none)
            Ok f ->
              ( {model | size = f}
              , Cmd.none
              )


        "players/0" ->
          case D.decodeValue decodePlayer outsideInfo.data of
            Err _ -> (model, Cmd.none)
            Ok f ->
              ( {model | currentWord = Just "SUCCESS0"}
              , Cmd.none)



        "players/1" ->
          case D.decodeValue decodePlayer outsideInfo.data of
            Err _ -> (model, Cmd.none)
            Ok f ->
              ( {model | currentWord = Just "SUCCESS1"}
              , Cmd.none)



        "players/2" ->
          case D.decodeValue decodePlayer outsideInfo.data of
            Err _ -> (model, Cmd.none)
            Ok f ->
              ( {model | currentWord = Just "SUCCESS2"}
              , Cmd.none)



        "players/3" ->
          case D.decodeValue decodePlayer outsideInfo.data of
            Err _ -> (model, Cmd.none)
            Ok f ->
              ( {model | currentWord = Just "SUCCESS3"}
              , Cmd.none)

        _ -> (model,Cmd.none)


    NextScreen float ->
      (drawSegments model , Cmd.none)

    Tick t ->
      let
        --Returns true if any player is still guessing
          stillGuessing : List Player -> Bool
          stillGuessing ps =
            case ps of
              [] -> False
              p :: rest -> (not p.isCorrect) || (stillGuessing rest)
      in
        (model ,
          Cmd.batch[
            if model.roundTime == 1 then toCmd RoundOver
            else if (model.gameTime - model.restStart == 5) then toCmd StartRound
            else if (not (stillGuessing model.players)) then toCmd RoundOver
            else Cmd.none

            , infoForJS {tag = "sharedModel/roundTime", data = E.int (model.roundTime-1)}
            , infoForJS {tag = "sharedModel/gameTime", data = E.int (model.gameTime + 1)}
            , infoForJS {tag = "players", data = E.list encodePlayer model.players}
            , infoForJS {tag = "swingy", data = E.int 123}
            ])

    --Adds player when a button ("Click to join!") is hit
    NewPlayer ->
      ({model | players = model.players ++ [(initPlayer model.numPlayers)]
              }
        , infoForJS {tag = "sharedModel/numPlayers", data = E.int (model.numPlayers + 1)}
        )

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

    Guess player guess ->
      (playerGuessUpdate model player guess, Cmd.none)

    RoundOver ->
      (  let
          playerRoundReset : Player -> Player
          playerRoundReset p = {p | isGuessing = False, isDrawing = False, isCorrect = False}
          newModel = drawSegments model
        in
          {newModel | currentWord = Nothing,
                   currentDrawer = Nothing,
                   players = List.map playerRoundReset model.players,
                   segments = Array.empty,
                   drawnSegments = [],
                   tracer = Nothing,
                   color = Color.black,
                   size = 20.0
                  }
          , Cmd.batch [
            infoForJS {tag = "sharedModel/roundTime", data = E.int 0}
          , infoForJS {tag = "sharedModel/roundPlaying", data = E.bool False}
          , infoForJS {tag = "sharedModel/restStart" , data = E.int model.gameTime}
          , infoForJS {tag = "sharedModel/color", data = E.int 0}
          , infoForJS {tag = "sharedModel/size", data = E.float 20.0}
          , infoForJS {tag = "sharedModel/currentWord", data = E.string "NOWORD"}
         ])

    NewWord (newWord, words) ->
      ({model | unusedWords = words
              }
          , Cmd.batch [
            infoForJS {tag = "sharedModel/unusedWords", data=E.list E.string words}
          , case newWord of
              Nothing -> infoForJS {tag = "sharedModel/currentWord", data=E.string "NOWORD"}
              Just nw -> infoForJS {tag = "sharedModel/currentWord", data=E.string nw}
          ])

    NewDrawer (drawer, _) ->
      (newDrawerUpdate model drawer, Cmd.none)

    NewHost (newDrawerID, _) ->
      (model, Cmd.none)

    StartRound ->
      ({model |
                 players = List.map allowGuess model.players
               , segments = Array.empty
               , drawnSegments = []
               , tracer = Nothing
          }
        , Cmd.batch[
          Random.generate NewWord (Random.List.choose model.unusedWords)
        , Random.generate NewDrawer (Random.List.choose model.players)
        , Random.generate NewHost (Random.List.choose (List.range 1 model.numPlayers))
        , infoForJS {tag = "sharedModel/roundTime", data = E.int 60}
        , infoForJS {tag = "sharedModel/roundNumber", data = E.int (model.roundNumber + 1)}
        , infoForJS {tag = "sharedModel/roundPlaying", data = E.bool True}
        ])

    BeginDraw point ->
      let
        newModel = {model | tracer = Just {prevMidpoint = point , lastPoint = point} }
      in
        (newModel, (sendTracer 0.0 point model))
    ContDraw point ->
      case model.tracer of
        Just x ->
          let
            newModel = addSegment point x model
          in
            (newModel, (sendTracer 1.0 point model))
        Nothing ->
          (model, Cmd.none)
    EndDraw point ->
      case model.tracer of
        Just x ->
          let
            newModel = endSegment point x model
          in
            (newModel, (sendTracer 2.0 point model))
        Nothing ->
          (model, Cmd.none)

    ChangeColor c ->
      ( {model | color = c} , (sendColor c))
    ChangeSize f ->
      ( {model | size = f}
      , infoForJS {tag = "sharedModel/size", data = E.float f})


    FreshGame ->
      (model,
      Cmd.batch[
        infoForJS {tag = "sharedModel/roundTime", data = E.int 60}
      , infoForJS {tag = "sharedModel/roundNumber", data = E.int 0}
      , infoForJS {tag = "sharedModel/roundPlaying", data = E.bool False}
      , infoForJS {tag = "sharedModel/numPlayers", data = E.int 0}
      , infoForJS {tag = "sharedModel/gameTime", data = E.int 0}
      , infoForJS {tag = "sharedModel/restStart", data = E.int 0}
      , infoForJS {tag = "sharedModel/currentWord" ,data = E.string "NOWORD"}
      ])

encodePlayer : Player -> E.Value
encodePlayer p =
  E.object
    [ ("name", E.string p.name)
    , ("username", E.int p.username)
    , ("currentGuess", E.string p.currentGuess)
    , ("score", E.int p.score)
    , ("isGuessing", E.bool p.isGuessing)
    , ("isDrawing", E.bool p.isDrawing)
    , ("isNamed", E.bool p.isNamed)
    , ("isCorrect", E.bool p.isCorrect)]

decodePlayer : D.Decoder Player
decodePlayer =
  D.map8
    Player
    (D.field "name" D.string)
    (D.field "username" D.int)
    (D.field "currentGuess" D.string)
    (D.field "score" D.int)
    (D.field "isGuessing" D.bool)
    (D.field "isDrawing" D.bool)
    (D.field "isNamed" D.bool)
    (D.field "isCorrect" D.bool)




sendTracer : Float -> Canvas.Point -> Model -> Cmd Msg
sendTracer n p model =
  if model.username == 1
    then
      case model.tracer of
        Nothing ->
          Cmd.none
        Just t ->
          let
            p1 = t.prevMidpoint
            p2 = t.lastPoint
            x1 = first p1
            y1 = second p1
            x2 = first p2
            y2 = second p2
            z1 = first p
            z2 = second p
            ps = [x1, y1, x2, y2, z1, z2, n]
          in
            infoForJS {tag = "sharedModel/tracer", data = (E.list E.float ps)}
  else Cmd.none

sendColor: Color -> Cmd Msg
sendColor color =
  let
    red = Color.toCssString Color.red
    orange = Color.toCssString Color.orange
    yellow = Color.toCssString Color.yellow
    green = Color.toCssString Color.green
    blue = Color.toCssString Color.blue
    purple = Color.toCssString Color.purple
    brown = Color.toCssString Color.brown
    eraser = Color.toCssString Color.white
    want = Color.toCssString color
    n = (
      if want == red then 1
      else if want == orange then 2
      else if want == yellow then 3
      else if want == green then 4
      else if want == blue then 5
      else if want == purple then 6
      else if want == brown then 7
      else if want == eraser then 8
      else 0 )
    in
      infoForJS {tag = "sharedModel/color", data = (E.int n)}

receiveColor: Int -> Color
receiveColor n =
  if n == 1 then Color.red
  else if n == 2 then Color.orange
  else if n == 3 then Color.yellow
  else if n == 4 then Color.green
  else if n == 5 then Color.blue
  else if n == 6 then Color.purple
  else if n == 7 then Color.brown
  else if n == 8 then Color.white
  else Color.black

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
    , [Html.text("Player ID: " ++ String.fromInt p.username)]
    , [Html.text("Current Guess: " ++ p.currentGuess)]
    , [Html.text("Score: " ++ String.fromInt p.score)]
    , if p.isDrawing then [Html.text(p.name ++ " is drawing!")]
      else [Html.text("")]]

--VIEW
view : Model -> Html Msg
view model =
  Html.div
    []
    [ Html.div
      []
      [Html.text ("Current username is: " ++ String.fromInt model.username)]

    , Html.div
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

    , Html.div
      []
      [Html.button [onClick FreshGame] [Html.text "CLICK TO START THE GAME FRESH"]]

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
              (Html.input [placeholder ("Guess for " ++ String.fromInt (p.username)),
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
                [Html.text ("Submit guess player" ++ String.fromInt(p.username +1))])
                  :: giveGuessButton rest
              else
                giveGuessButton rest
        in
          Html.div []
            (giveGuessButton model.players)

--View all player information
    , applyHtmlDiv (List.map applyHtmlDiv (List.map viewPlayerInfo model.players))


-- Whiteboard

    , Canvas.toHtml (750, 750)
        (if model.username == 1
          then [ Mouse.onDown (.offsetPos >> BeginDraw)
               , Mouse.onMove (.offsetPos >> ContDraw)
               , Mouse.onUp (.offsetPos >> EndDraw)
               ]
         else [])
        ( ( Canvas.shapes [ Canvas.Settings.stroke Color.blue ] [ Canvas.rect ( 0, 0 ) 750 750 ]) ::
          model.drawnSegments )
    , Html.div
        []
        [ Html.button
            [ onClick (ChangeColor Color.red)
            , style "background-color" "red"
            ]
            [Html.text "Red"]
        , Html.button
            [onClick (ChangeColor Color.orange)
            , style "background-color" "orange"
            ]
            [Html.text "Orange"]
        , Html.button
            [onClick (ChangeColor Color.yellow)
            , style "background-color" "yellow"
            ]
            [Html.text "Yellow"]
        , Html.button
            [onClick (ChangeColor Color.green)
            , style "background-color" "green"
            ]
            [Html.text "Green"]
        , Html.button
            [onClick (ChangeColor Color.blue)
            , style "background-color" "blue"
            ]
            [Html.text "Blue"]
        , Html.button
            [onClick (ChangeColor Color.purple)
            , style "background-color" "purple"
            ]
            [Html.text "Purple"]
        , Html.button
            [onClick (ChangeColor Color.brown)
            , style "background-color" "brown"
            ]
            [Html.text "Brown"]
        , Html.button [onClick (ChangeColor Color.white)][Html.text "Eraser"]
        ]
    , Element.layout []
        (Element.Input.slider
          [ Element.height (Element.px 5)
          , Element.width (Element.px 700)
          , Element.behindContent
            (Element.el
              [ Element.width (Element.px 700)
              , Element.height (Element.px 2)
              , Element.Background.color (Element.rgb255 0 0 0)
              , Element.Border.rounded 2
              ]
              Element.none
            )
          ]
          { onChange = ChangeSize
          , label =
            Element.Input.labelAbove []
              (Element.text "Brush Size:")
          , min = 5
          , max = 50
          , step = Nothing
          , value = model.size
          , thumb = Element.Input.defaultThumb
          }
        )
    ]
