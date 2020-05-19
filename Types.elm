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

----------------------------------------------------------------------

type alias Score = Int
type alias Name = String
type alias Player =
  { name : Name
  , score : Int
  , guesses : List String
  , isGuessing : Bool
  , isDrawing : Bool
  }

type alias Trace =
  { prevMidpoint: Point
  , lastPoint: Point
  }

type Msg
  = None
  | Tick Posix
  | Guess Player String
  | RoundOver
  | NewWord (Maybe String, List String)
  | NewDrawer (Maybe Player, List Player)
  | StartRound
  | RestPeriod
  | BeginDraw
  | ContDraw
  | EndDraw

-- MODEL
type alias Model =
  { players : List Player
  , currentWord : Maybe String
  , unusedWords : List String
  , whiteboardClean : Bool
  , currentDrawer : Maybe Player
  , roundNumber : Int
  , roundTime : Int
  , gameTime : Int
  , roundPlaying : Bool
  , restSeconds : Int
  , segments : Array Renderable
  , drawnSegments : List Renderable
  , tracer : Maybe Trace
  , color : Color
  , size : Int
  }

--FLAGS

type alias Flags = ()
