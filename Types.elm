module Types exposing (..)

--Imports--
import Browser
import Html exposing (Html)
import Debug
import Time exposing (Posix)


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

type Msg =
  None |
  Tick Posix |
  Guess Player String|
--  CorrectGuess Player |
--  WrongGuess Player |
  RoundOver |
  NextRound

-- MODEL
type alias Model =
  { players : List Player
  , currentWord : Maybe String
  , whiteboardClean : Bool
  , currentDrawer : Maybe Player
  , roundNumber : Int
  , roundTime : Int
  , roundPlaying : Bool 
  }

--FLAGS

type alias Flags = ()
