module Types exposing (..)

--Imports--
import Browser
import Html exposing (Html)
import Debug
import Time exposing (Posix)
import Color exposing (Color)
import Canvas exposing (..)
import Canvas.Settings exposing (..)
import Canvas.Settings.Advanced exposing (..)
import Canvas.Settings.Line exposing (..)
import Array exposing (Array)
import Json.Encode as E

----------------------------------------------------------------------

type alias Score = Int
type alias Player =
  { name : String
  , username : Int
  , currentGuess : String
  , score : Int
  , isGuessing : Bool
  , isDrawing : Bool
  , isNamed : Bool
  , isCorrect : Bool
  }

type alias Trace =
  { prevMidpoint: Canvas.Point
  , lastPoint: Canvas.Point
  }

type alias GenericOutsideData =
    { tag : String, data : E.Value }

type Msg
  = None
  | Tick Posix
  | NewPlayer
  | UpdateName Player String
  | UpdateCurrentGuess Player String
  | Guess Player String
  | SubmitName Player
  | RoundOver
  | NewWord (Maybe String, List String)
  | NewDrawer (Maybe Player, List Player)
  | NewHost (Maybe Int, List Int)
  | StartRound
  | BeginDraw Canvas.Point
  | ContDraw Canvas.Point
  | EndDraw Canvas.Point
  | NextScreen Float
  | ChangeColor Color
  | ChangeSize Float

  --Firebase
  | ReceiveValue GenericOutsideData
  | FreshGame


--  | Outside

-- MODEL
type alias Model =
  { players : List Player
  , numPlayers : Int
  , currentWord : Maybe String
  , unusedWords : List String
  , currentDrawer : Maybe Player
  , roundNumber : Int
  , roundTime : Int
  , gameTime : Int
  , roundPlaying : Bool
  , restStart : Int
  , segments : Array Renderable
  , drawnSegments : List Renderable
  , tracer : Maybe Trace
  , color : Color
  , size : Float
  , currentScreen : Int

  , username : Int
  , startedPlaying : Bool
  }

--FLAGS

type alias Flags = ()
