port module OutsideInfo exposing (..)

import Json.Decode exposing (..)
import Json.Encode

sendInfoOutside : InfoForOutside -> Cmd msg
sendInfoOutside info =
    case info of
        Draw ->
            infoForOutside { tag = "Draw", data = Json.Encode.list }

getInfoFromOutside : (InfoForElm -> msg) -> (String -> msg) -> Sub msg
getInfoFromOutside tagger onError =
    infoForElm
        (\outsideInfo ->
            case outsideInfo.tag of
                "BoardChanged" image ->
                    case decodeValue (field "Board" list) outsideInfo.data of
                        Ok l ->
                            tagger <| BoardChanged l
                        Err e ->
                            onError e
                _ ->
                    onError <| "Unexpected info from outside: " ++ toString outsideInfo
        )

type InfoForOutside
    = Draw

type InfoForElm
    = BoardChanged (List Renderable)

type alias GenericOutsideData =
    { tag : String, data : Json.Encode.Value }

--port infoForOutside : GenericOutsideData -> Cmd msg
--port infoForElm : (GenericOutsideData -> msg) -> Sub msg
