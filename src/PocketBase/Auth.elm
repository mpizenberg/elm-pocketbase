module PocketBase.Auth exposing (authWithPassword, refreshAuth, isAuthenticated, getAuthRecord, logout)

{-| PocketBase authentication operations.

@docs authWithPassword, refreshAuth, isAuthenticated, getAuthRecord, logout

-}

import ConcurrentTask exposing (ConcurrentTask)
import Json.Decode as Decode
import Json.Encode as Encode
import PocketBase exposing (Client, Error)
import PocketBase.Internal as Internal


{-| Authenticate with username/email + password.
PocketBase stores the JWT token internally in the JS SDK's authStore.

The returned record is decoded with the provided decoder, so you can
extract whichever fields your auth collection has.

    PocketBase.Auth.authWithPassword client
        { collection = "users"
        , identity = "user@example.com"
        , password = "secret"
        , decoder = userDecoder
        }

-}
authWithPassword :
    Client
    -> { collection : String, identity : String, password : String, decoder : Decode.Decoder a }
    -> ConcurrentTask Error a
authWithPassword client { collection, identity, password, decoder } =
    ConcurrentTask.define
        { function = "pocketbase:authWithPassword"
        , expect = ConcurrentTask.expectJson decoder
        , errors = ConcurrentTask.expectErrors PocketBase.errorDecoder
        , args =
            Encode.object
                [ Internal.clientIdField client
                , ( "collection", Encode.string collection )
                , ( "identity", Encode.string identity )
                , ( "password", Encode.string password )
                ]
        }


{-| Refresh the current auth token. Fails if not currently authenticated.

    PocketBase.Auth.refreshAuth client
        { collection = "users"
        , decoder = userDecoder
        }

-}
refreshAuth :
    Client
    -> { collection : String, decoder : Decode.Decoder a }
    -> ConcurrentTask Error a
refreshAuth client { collection, decoder } =
    ConcurrentTask.define
        { function = "pocketbase:refreshAuth"
        , expect = ConcurrentTask.expectJson decoder
        , errors = ConcurrentTask.expectErrors PocketBase.errorDecoder
        , args =
            Encode.object
                [ Internal.clientIdField client
                , ( "collection", Encode.string collection )
                ]
        }


{-| Check if the client has a valid auth token. Synchronous JS check.
-}
isAuthenticated : Client -> ConcurrentTask Never Bool
isAuthenticated client =
    ConcurrentTask.define
        { function = "pocketbase:isAuthenticated"
        , expect = ConcurrentTask.expectJson Decode.bool
        , errors = ConcurrentTask.expectNoErrors
        , args = Encode.object [ Internal.clientIdField client ]
        }


{-| Get the current auth record, if authenticated.
The record is decoded with the provided decoder.

    PocketBase.Auth.getAuthRecord client userDecoder

-}
getAuthRecord : Client -> Decode.Decoder a -> ConcurrentTask Never (Maybe a)
getAuthRecord client decoder =
    ConcurrentTask.define
        { function = "pocketbase:getAuthRecord"
        , expect = ConcurrentTask.expectJson (Decode.nullable decoder)
        , errors = ConcurrentTask.expectNoErrors
        , args = Encode.object [ Internal.clientIdField client ]
        }


{-| Clear the auth store.
-}
logout : Client -> ConcurrentTask Never ()
logout client =
    ConcurrentTask.define
        { function = "pocketbase:logout"
        , expect = ConcurrentTask.expectWhatever
        , errors = ConcurrentTask.expectNoErrors
        , args = Encode.object [ Internal.clientIdField client ]
        }
