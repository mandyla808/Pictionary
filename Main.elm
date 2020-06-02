port module Main exposing (..)

--Imports--
import Browser
import Browser.Events
import Html exposing (Html, div)
import Html.Events exposing (onClick, onInput)
import Html.Attributes exposing(placeholder, value, style, class)
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

import String exposing (concat, fromInt)
import List exposing (length)
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
  , username = n+1
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
  , roundPlaying = False -- Is the round still on?
  , segments = Array.empty
  , drawnSegments = []
  , tracer = Nothing
  , color = Color.black
  , size = 20.0
  , currentScreen = 0
  , username = -1
  , drawerID = 1
  , startedPlaying = False
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
          if model.username /= model.drawerID then
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

        "sharedModel/numPlayers" ->
          case D.decodeValue D.int outsideInfo.data of
            Err _ -> (model, Cmd.none)
            Ok n ->
              ( {model | numPlayers = n}
              , Cmd.none
              )

        "sharedModel/drawerID" ->
          case D.decodeValue D.int outsideInfo.data of
            Err _ -> (model, Cmd.none)
            Ok n ->
              ( {model | drawerID = n}
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

        "players" ->
          case D.decodeValue (D.list decodePlayer) outsideInfo.data of
            Err _ -> (model, Cmd.none)
            Ok ps ->
              if (length ps < model.numPlayers) then
                (model, Cmd.none)
              else
                ( {model | players = ps}, Cmd.none)

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
            p :: rest ->
              (not (p.isCorrect || p.username == model.drawerID)) || (stillGuessing rest)
      in
        (model ,
          Cmd.batch
            [(if model.roundTime == 1
                then toCmd RoundOver
              else if (not (stillGuessing model.players) && model.startedPlaying)
                then toCmd RoundOver
              else Cmd.none)
            , (if model.username == model.drawerID
              then
                infoForJS {tag = "sharedModel/roundTime", data = E.int (model.roundTime-1)}
              else Cmd.none)
            , (if model.username == model.drawerID
              then
                infoForJS {tag = "sharedModel/gameTime", data = E.int (model.gameTime + 1)}
              else Cmd.none)
            ])

    --Adds player when a button ("Click to join!") is hit
    NewPlayer ->
      (
        {model | startedPlaying = True, username = (model.numPlayers + 1)
               , players = model.players ++ [(initPlayer model.numPlayers)]}

        , Cmd.batch[
            infoForJS {tag = concat ["players/", fromInt model.numPlayers], data =  encodePlayer (initPlayer model.numPlayers)}
          , infoForJS {tag = "sharedModel/numPlayers", data = E.int (model.numPlayers + 1)}])

    UpdateName player newName ->
      let
        updatedPlayer = {player | name = newName}
        updatedPlayers = updatePlayer model.players updatedPlayer
        newModel = {model | players = (updatePlayer model.players updatedPlayer)}
      in
        (model
       , infoForJS{tag = concat ["players/", fromInt (model.username - 1)], data = encodePlayer updatedPlayer}
       )


    --Player submits their name
    SubmitName player ->
      let
        updatedPlayer = {player | isNamed = True}
        newModel = {model | players = (updatePlayer model.players updatedPlayer)}
      in
        ( model
        , infoForJS{tag = concat ["players/", fromInt (model.username - 1)], data = encodePlayer updatedPlayer}
        )

    --Tracks what the player has in their text box
    UpdateCurrentGuess player guess ->
        let
          updatedPlayer = {player | currentGuess = guess}
        in
          (model, infoForJS{tag = concat ["players/", fromInt (player.username - 1)], data = encodePlayer updatedPlayer})

    Guess player guess ->
      case model.currentWord of
        Nothing -> (model, Cmd.none)

        Just cw ->
          if (String.toUpper guess) == (String.toUpper cw) then
            let
              updatedPlayer =
                {player |  score = (player.score + 1)
                         , isGuessing = False
                         , currentGuess = ""
                         , isCorrect = True
                }
            in
              (model, infoForJS{tag = concat ["players/", fromInt (player.username - 1)], data = encodePlayer updatedPlayer})
        --      (model, infoForJS {tag = "players/", data = E.list encodePlayer (updatePlayer model.players updatedPlayer)})

          else
            let
              updatedPlayer = {player | currentGuess = ""}
            in
              (model, infoForJS{tag = concat ["players/", fromInt (player.username - 1)], data = encodePlayer updatedPlayer})

            --  (model, infoForJS {tag = "players/", data = E.list encodePlayer (updatePlayer model.players updatedPlayer)})


    RoundOver ->
      ( let
          newModel = drawSegments model
        in
          {newModel | currentWord = Nothing
                    , currentDrawer = Nothing
                    , segments = Array.empty
                    , drawnSegments = []
                    , tracer = Nothing
                    , color = Color.black
                    , size = 20.0
                    }
          ,
          let
            playerRoundReset : Player -> Player
            playerRoundReset p = {p | isGuessing = False, isDrawing = False, isCorrect = False}
            newList = (List.map playerRoundReset model.players)
          in
            Cmd.batch [
             infoForJS {tag = "sharedModel/roundTime", data = E.int 0}
            , infoForJS {tag = "sharedModel/roundPlaying", data = E.bool False}
            , infoForJS {tag = "sharedModel/color", data = E.int 0}
            , infoForJS {tag = "sharedModel/size", data = E.float 20.0}
            , infoForJS {tag = "sharedModel/currentWord", data = E.string "NOWORD"}
            , infoForJS {tag = "players", data = E.list encodePlayer newList}
            , infoForJS {tag = "sharedModel/drawerID", data = E.int (changeDrawer model)}
           ])

    NewWord (newWord, words) ->
      ( {model | unusedWords = words}
      , (if model.username == model.drawerID then
         Cmd.batch
          [ infoForJS {tag = "sharedModel/unusedWords", data=E.list E.string words}
          , case newWord of
              Nothing -> infoForJS {tag = "sharedModel/currentWord", data=E.string "NOWORD"}
              Just nw -> infoForJS {tag = "sharedModel/currentWord", data=E.string nw}
          ]
        else Cmd.none)
      )

    NewDrawer (drawer, _) ->
      (newDrawerUpdate model drawer, Cmd.none)

    NewHost (newDrawerID, _) ->
      (model, Cmd.none)

    StartRound ->
      ({ model |segments = Array.empty
              , drawnSegments = []
              , tracer = Nothing
       }
        , (if model.username == model.drawerID then
            Cmd.batch
              [ Random.generate NewWord (Random.List.choose model.unusedWords)
              , infoForJS {tag = "sharedModel/roundTime", data = E.int 60}
              , infoForJS {tag = "sharedModel/roundNumber", data = E.int (model.roundNumber + 1)}
              , infoForJS {tag = "sharedModel/roundPlaying", data = E.bool True}
              , infoForJS {tag = "players/", data = E.list encodePlayer (List.map allowGuess model.players)}
              ]
          else Cmd.none)
      )

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
      if model.username == model.drawerID then
        ({model | color = c} , (sendColor c))
      else (model, Cmd.none)
    ChangeSize f ->
      if model.username == model.drawerID then
        ( {model | size = f}
        , infoForJS {tag = "sharedModel/size", data = E.float f})
      else (model, Cmd.none)

    FreshGame ->
      (initModel,
      Cmd.batch[
        infoForJS {tag = "sharedModel/roundTime", data = E.int 60}
      , infoForJS {tag = "sharedModel/roundNumber", data = E.int 0}
      , infoForJS {tag = "sharedModel/roundPlaying", data = E.bool False}
      , infoForJS {tag = "sharedModel/numPlayers", data = E.int 0}
      , infoForJS {tag = "sharedModel/gameTime", data = E.int 0}
      , infoForJS {tag = "sharedModel/currentWord" ,data = E.string "NOWORD"}
      , infoForJS {tag = "players/" , data = E.list encodePlayer  []}
      , infoForJS {tag = "sharedModel/drawerID", data = E.int 1}
      , infoForJS {tag = "sharedModel/tracer", data = (E.list E.float [])}
      , infoForJS {tag = "sharedModel/unusedWords", data = E.list E.string wordList}
      ])
----------------------END UPATE FUNCTION---------------------------------------

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
  if model.username == model.drawerID
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
    black = Color.toCssString Color.black
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
      else if want == black then 9
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
  let
    playerName : String
    playerName =
      if p.isNamed then
         p.name
      else
        "Player " ++ fromInt p.username
  in
    [ Html.div
      []
      [ Html.text (playerName
          ++ " | Score: " ++ fromInt p.score ++
          (if p.isCorrect then " -- Correct!"
           else ""))
      ]
    ]

--VIEW
view : Model -> Html Msg
view model =
  Html.div
    []
    [

      if model.startedPlaying then
        Html.div []
        (if model.username == model.drawerID && not model.roundPlaying then
          case findPlayer model.username model.players of
            Nothing -> []
            Just p ->
              if p.isNamed then
                [ Html.text ("You are the drawer! Click to start the round: ")
                , Html.button [class "button", onClick StartRound][Html.text "Start Round"]
                ]
              else []
        else if not model.roundPlaying then
          case findPlayer model.username model.players of
            Nothing -> []
            Just p ->
              if p.isNamed then
                [Html.text ("You will be guessing! Waiting for round to start...")]
              else
                []
        else [Html.div [] []])
      else
        Html.div [] []

    , if model.startedPlaying && model.roundNumber /= 0 then
        Html.div [] [Html.text (" Round " ++ fromInt model.roundNumber)]
      else
        Html.div [] []


    , if model.roundPlaying && model.startedPlaying then
        Html.div [] [Html.text ("Timer: " ++ fromInt model.roundTime)]
      else
        Html.div [] []




    , case model.currentWord of
          Just w ->
            if model.username == model.drawerID then
              Html.div [] [Html.text("Draw: " ++ w)]
            else
              Html.div [] []
          _ -> Html.div [] []


--  Manually add players
    , if not model.startedPlaying then
        Html.div
        []
        [Html.button [class "button", onClick NewPlayer] [Html.text "Welcome! Click to join!"]]
      else
        Html.div
        []
        []

--  ALLOWS INDIVIDUAL PLAYERS TO TYPE IN GUESSES
    , case findPlayer model.username model.players of
        Nothing -> Html.div [] []
        Just p ->
          let
            nameInput : List (Html Msg)
            nameInput =
              if not p.isNamed then
                [ Html.input [class "input", placeholder ("Enter Name"), value p.name, onInput (UpdateName p)] []
                , Html.button [class "button", onClick (SubmitName p)]
                    [Html.text ("Enter your name!")]
                ]
              else
                [Html.div [] []]

            guessInput : List (Html Msg)
            guessInput =
              [ Html.input
                   [class "input", placeholder ("Insert guess for " ++ fromInt (p.username)),
                            value p.currentGuess, onInput (UpdateCurrentGuess p)] []
             ,  Html.button [class "button", onClick (Guess p p.currentGuess)]
                  [Html.text ("Submit guess player" ++ fromInt(p.username))]
              ]
          in
            Html.div
            []
            (if ((model.username == model.drawerID) || (not p.isGuessing)) then
              nameInput
             else (nameInput ++ guessInput))

--View all player information
    ,  if model.startedPlaying then
        Html.div [class "playerheader"] [Html.text ("Scoreboard")]
      else
        Html.div [] []

  ,    if model.startedPlaying then
        applyHtmlDiv (List.map applyHtmlDiv (List.map viewPlayerInfo model.players))
      else
        Html.div [] []



    ,  if model.startedPlaying then
        Html.div [] [Html.button [class "button", onClick FreshGame] [Html.text "Finish Game"]]
      else
        Html.div [] []

-- Whiteboard
    , Canvas.toHtml (500, 500)
        (if model.username == model.drawerID
          then [ Mouse.onDown (.offsetPos >> BeginDraw)
               , Mouse.onMove (.offsetPos >> ContDraw)
               , Mouse.onUp (.offsetPos >> EndDraw)
               ]
         else [])
        ( ( Canvas.shapes [ Canvas.Settings.stroke Color.blue ] [ Canvas.rect ( 0, 0 ) 500 500 ]) ::
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
        , Html.button [onClick (ChangeColor Color.black)][Html.text "Black"]
        , Html.button [onClick (ChangeColor Color.white)][Html.text "Eraser"]
        ]
    , Element.layout []
        (Element.Input.slider
          [ Element.height (Element.px 5)
          , Element.width (Element.px 500)
          , Element.behindContent
            (Element.el
              [ Element.width (Element.px 500)
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
