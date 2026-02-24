module PocketBase.Encode exposing (bytesToBase64, base64ToBytes)

{-| Binary encoding utilities for converting between Elm Bytes and Base64 strings.

@docs bytesToBase64, base64ToBytes

-}

import Bytes exposing (Bytes)
import Bytes.Decode as BD
import Bytes.Encode as BE
import ConcurrentTask exposing (ConcurrentTask)
import Json.Decode as Decode
import Json.Encode as Encode



-- TODO: this module should not call into ConcurrentTask!
-- These conversions can be written in pure Elm directly!


{-| Encode raw bytes to a Base64 string (chunked to avoid stack overflow).
-}
bytesToBase64 : Bytes -> ConcurrentTask Never String
bytesToBase64 bytes =
    ConcurrentTask.define
        { function = "pocketbase:bytesToBase64"
        , expect = ConcurrentTask.expectJson Decode.string
        , errors = ConcurrentTask.expectNoErrors
        , args = Encode.object [ ( "bytes", Encode.list Encode.int (bytesToList bytes) ) ]
        }


{-| Decode a Base64 string to raw bytes.
-}
base64ToBytes : String -> ConcurrentTask Never Bytes
base64ToBytes base64 =
    ConcurrentTask.define
        { function = "pocketbase:base64ToBytes"
        , expect = ConcurrentTask.expectJson (Decode.list Decode.int)
        , errors = ConcurrentTask.expectNoErrors
        , args = Encode.object [ ( "base64", Encode.string base64 ) ]
        }
        |> ConcurrentTask.map listToBytes


bytesToList : Bytes -> List Int
bytesToList bytes =
    let
        width =
            Bytes.width bytes
    in
    BD.decode (decodeByteList width) bytes
        |> Maybe.withDefault []


decodeByteList : Int -> BD.Decoder (List Int)
decodeByteList width =
    BD.loop ( width, [] ) decodeByteStep


decodeByteStep : ( Int, List Int ) -> BD.Decoder (BD.Step ( Int, List Int ) (List Int))
decodeByteStep ( remaining, acc ) =
    if remaining <= 0 then
        BD.succeed (BD.Done (List.reverse acc))

    else
        BD.unsignedInt8
            |> BD.map (\byte -> BD.Loop ( remaining - 1, byte :: acc ))


listToBytes : List Int -> Bytes
listToBytes ints =
    ints
        |> List.map BE.unsignedInt8
        |> BE.sequence
        |> BE.encode
