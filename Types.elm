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
  , identity : Int
  , currentGuess : String
  , score : Int
  , guesses : List String
  , isGuessing : Bool
  , isDrawing : Bool
  , isNamed : Bool
  , isCorrect : Bool
  }

type alias Trace =
  { prevMidpoint: Canvas.Point
  , lastPoint: Canvas.Point
  }

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
  | StartRound
  | BeginDraw Canvas.Point
  | ContDraw Canvas.Point
  | EndDraw Canvas.Point
  | NextScreen Float
  | ChangeColor Color
  | ChangeSize Float

  -------------------FIREBASE TEST THINGS DELETE
  | Click
  | ReceiveValue String

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



  ----------------FIREBASE TEST DELETE
  , count : Maybe Int
  }

--FLAGS

type alias Flags = ()
