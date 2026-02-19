module PocketBase.Internal exposing (Client(..), clientId, clientIdField)

import Json.Encode as Encode


{-| Opaque handle to a PocketBase client instance.
Created by `PocketBase.init`, threaded through all operations.
-}
type Client
    = Client String


clientId : Client -> String
clientId (Client id) =
    id


clientIdField : Client -> ( String, Encode.Value )
clientIdField (Client id) =
    ( "clientId", Encode.string id )
