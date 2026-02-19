module PocketBase.Custom exposing (fetch)

{-| Make raw HTTP requests to custom PocketBase endpoints.

@docs fetch

-}

import ConcurrentTask exposing (ConcurrentTask)
import Json.Decode as Decode
import Json.Encode as Encode
import PocketBase exposing (Client, Error)
import PocketBase.Internal as Internal


{-| Make a raw HTTP request to a custom PocketBase endpoint.
The URL is resolved relative to the client's base URL.

    PocketBase.Custom.fetch client
        { method = "GET"
        , path = "/api/pow/challenge"
        , body = Nothing
        , decoder = powChallengeDecoder
        }

-}
fetch :
    Client
    -> { method : String, path : String, body : Maybe Encode.Value, decoder : Decode.Decoder a }
    -> ConcurrentTask Error a
fetch client { method, path, body, decoder } =
    ConcurrentTask.define
        { function = "pocketbase:customFetch"
        , expect = ConcurrentTask.expectJson decoder
        , errors = ConcurrentTask.expectErrors PocketBase.errorDecoder
        , args =
            Encode.object
                [ Internal.clientIdField client
                , ( "method", Encode.string method )
                , ( "path", Encode.string path )
                , ( "body", encodeMaybe identity body )
                ]
        }


encodeMaybe : (a -> Encode.Value) -> Maybe a -> Encode.Value
encodeMaybe encoder maybe =
    case maybe of
        Just value ->
            encoder value

        Nothing ->
            Encode.null
