module Main exposing (..)

--Imports--
import Browser
import Html exposing (Html)
import Debug
import Types exposing(..)
import Time exposing (Posix)
import Updates exposing (..)

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
  , whiteboardClean = True
  , currentDrawer = Nothing
  , roundNumber = 1
  , roundTime = 60
  , roundPlaying = False -- Is the round still on?
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
    Tick t -> ({model | roundTime = model.roundTime-1}, Cmd.none)
    Guess player guess -> (playerUpdate model player guess, Cmd.none)
  --  CorrectGuess player -> (initModel, Cmd.none)
  --  WrongGuess player -> (initModel, Cmd.none)
    RoundOver -> (roundOverUpdate model, Cmd.none)
    NextRound -> (initModel, Cmd.none)

--VIEW
view : Model -> Html Msg
view model =
  Html.div
    []
    [ Html.text ("Timer:" ++ String.fromInt model.roundTime)
    ]
