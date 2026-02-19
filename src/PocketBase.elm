module PocketBase exposing (Client, init, healthCheck, Error(..), errorDecoder)

{-| PocketBase client for Elm via elm-concurrent-task.

@docs Client, init, healthCheck, Error, errorDecoder

-}

import ConcurrentTask exposing (ConcurrentTask)
import Json.Decode as Decode
import Json.Encode as Encode
import PocketBase.Internal as Internal


{-| Opaque handle to a PocketBase client instance.
Created by `init`, threaded through all operations.
-}
type alias Client =
    Internal.Client


{-| Errors that PocketBase operations can produce.
-}
type Error
    = NotFound
    | Unauthorized
    | Forbidden
    | BadRequest String
    | Conflict
    | TooManyRequests
    | ServerError String
    | NetworkError String


{-| Initialize a PocketBase client pointing at the given base URL.
The JS companion creates the `new PocketBase(url)` instance and returns an ID.
-}
init : String -> ConcurrentTask Error Client
init url =
    ConcurrentTask.define
        { function = "pocketbase:init"
        , expect = ConcurrentTask.expectJson (Decode.map Internal.Client Decode.string)
        , errors = ConcurrentTask.expectErrors errorDecoder
        , args = Encode.object [ ( "url", Encode.string url ) ]
        }


{-| Health check. Returns True if the server is reachable.
-}
healthCheck : Client -> ConcurrentTask Never Bool
healthCheck client =
    ConcurrentTask.define
        { function = "pocketbase:healthCheck"
        , expect = ConcurrentTask.expectJson Decode.bool
        , errors = ConcurrentTask.expectNoErrors
        , args = Encode.object [ Internal.clientIdField client ]
        }


{-| Decode a PocketBase error from the JS companion wire format.
The wire format is `"CODE:message"` where CODE is one of:
NOT\_FOUND, UNAUTHORIZED, FORBIDDEN, BAD\_REQUEST, CONFLICT,
TOO\_MANY\_REQUESTS, SERVER\_ERROR, NETWORK\_ERROR.
-}
errorDecoder : Decode.Decoder Error
errorDecoder =
    Decode.string
        |> Decode.andThen
            (\err ->
                case splitOnce ":" err of
                    Just ( "NOT_FOUND", _ ) ->
                        Decode.succeed NotFound

                    Just ( "UNAUTHORIZED", _ ) ->
                        Decode.succeed Unauthorized

                    Just ( "FORBIDDEN", _ ) ->
                        Decode.succeed Forbidden

                    Just ( "BAD_REQUEST", msg ) ->
                        Decode.succeed (BadRequest msg)

                    Just ( "CONFLICT", _ ) ->
                        Decode.succeed Conflict

                    Just ( "TOO_MANY_REQUESTS", _ ) ->
                        Decode.succeed TooManyRequests

                    Just ( "SERVER_ERROR", msg ) ->
                        Decode.succeed (ServerError msg)

                    Just ( "NETWORK_ERROR", msg ) ->
                        Decode.succeed (NetworkError msg)

                    _ ->
                        Decode.fail ("Unknown PocketBase error: " ++ err)
            )


splitOnce : String -> String -> Maybe ( String, String )
splitOnce sep str =
    case String.indices sep str of
        i :: _ ->
            Just ( String.left i str, String.dropLeft (i + String.length sep) str )

        [] ->
            Nothing
