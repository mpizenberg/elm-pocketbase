module PocketBase.Auth exposing (AuthRecord, authWithPassword, refreshAuth, isAuthenticated, getAuthRecord, logout, derivePasswordFromKey)

{-| PocketBase authentication operations.

@docs AuthRecord, authWithPassword, refreshAuth, isAuthenticated, getAuthRecord, logout, derivePasswordFromKey

-}

import ConcurrentTask exposing (ConcurrentTask)
import Json.Decode as Decode
import Json.Encode as Encode
import PocketBase exposing (Client, Error)
import PocketBase.Internal as Internal


{-| A record representing an authenticated user.
-}
type alias AuthRecord =
    { id : String
    , username : String
    , groupId : String
    }


authRecordDecoder : Decode.Decoder AuthRecord
authRecordDecoder =
    Decode.map3 AuthRecord
        (Decode.field "id" Decode.string)
        (Decode.field "username" Decode.string)
        (Decode.field "groupId" Decode.string)


{-| Authenticate with username + password.
PocketBase stores the JWT token internally in the JS SDK's authStore.
-}
authWithPassword :
    Client
    -> { collection : String, identity : String, password : String }
    -> ConcurrentTask Error AuthRecord
authWithPassword client { collection, identity, password } =
    ConcurrentTask.define
        { function = "pocketbase:authWithPassword"
        , expect = ConcurrentTask.expectJson authRecordDecoder
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
-}
refreshAuth : Client -> ConcurrentTask Error AuthRecord
refreshAuth client =
    ConcurrentTask.define
        { function = "pocketbase:refreshAuth"
        , expect = ConcurrentTask.expectJson authRecordDecoder
        , errors = ConcurrentTask.expectErrors PocketBase.errorDecoder
        , args = Encode.object [ Internal.clientIdField client ]
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
-}
getAuthRecord : Client -> ConcurrentTask Never (Maybe AuthRecord)
getAuthRecord client =
    ConcurrentTask.define
        { function = "pocketbase:getAuthRecord"
        , expect = ConcurrentTask.expectJson (Decode.nullable authRecordDecoder)
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


{-| Derive a deterministic password from a Base64 key string.
Computes: base64url(SHA-256(base64decode(keyString)))
This is the auth mechanism used by partage: the group's symmetric key
is hashed to produce a per-group password.
-}
derivePasswordFromKey : String -> ConcurrentTask Never String
derivePasswordFromKey keyBase64 =
    ConcurrentTask.define
        { function = "pocketbase:derivePassword"
        , expect = ConcurrentTask.expectJson Decode.string
        , errors = ConcurrentTask.expectNoErrors
        , args = Encode.object [ ( "keyBase64", Encode.string keyBase64 ) ]
        }
