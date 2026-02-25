module PocketBase.Auth exposing (authWithPassword, refreshAuth, isAuthenticated, getAuthRecord, logout, createAccount, updateAccount, deleteAccount, requestPasswordReset, confirmPasswordReset)

{-| PocketBase authentication operations.

@docs authWithPassword, refreshAuth, isAuthenticated, getAuthRecord, logout, createAccount, updateAccount, deleteAccount, requestPasswordReset, confirmPasswordReset

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


{-| Create a new auth account.

    PocketBase.Auth.createAccount client
        { collection = "users"
        , body =
            Encode.object
                [ ( "email", Encode.string "user@example.com" )
                , ( "password", Encode.string "secret123" )
                , ( "passwordConfirm", Encode.string "secret123" )
                , ( "name", Encode.string "Alice" )
                ]
        , decoder = userDecoder
        }

-}
createAccount :
    Client
    -> { collection : String, body : Encode.Value, decoder : Decode.Decoder a }
    -> ConcurrentTask Error a
createAccount client { collection, body, decoder } =
    ConcurrentTask.define
        { function = "pocketbase:create"
        , expect = ConcurrentTask.expectJson decoder
        , errors = ConcurrentTask.expectErrors PocketBase.errorDecoder
        , args =
            Encode.object
                [ Internal.clientIdField client
                , ( "collection", Encode.string collection )
                , ( "body", body )
                ]
        }


{-| Update an existing auth account by ID.

    PocketBase.Auth.updateAccount client
        { collection = "users"
        , id = userId
        , body = Encode.object [ ( "name", Encode.string "Bob" ) ]
        , decoder = userDecoder
        }

-}
updateAccount :
    Client
    -> { collection : String, id : String, body : Encode.Value, decoder : Decode.Decoder a }
    -> ConcurrentTask Error a
updateAccount client { collection, id, body, decoder } =
    ConcurrentTask.define
        { function = "pocketbase:update"
        , expect = ConcurrentTask.expectJson decoder
        , errors = ConcurrentTask.expectErrors PocketBase.errorDecoder
        , args =
            Encode.object
                [ Internal.clientIdField client
                , ( "collection", Encode.string collection )
                , ( "id", Encode.string id )
                , ( "body", body )
                ]
        }


{-| Delete an auth account by ID.

    PocketBase.Auth.deleteAccount client
        { collection = "users"
        , id = userId
        }

-}
deleteAccount :
    Client
    -> { collection : String, id : String }
    -> ConcurrentTask Error ()
deleteAccount client { collection, id } =
    ConcurrentTask.define
        { function = "pocketbase:delete"
        , expect = ConcurrentTask.expectWhatever
        , errors = ConcurrentTask.expectErrors PocketBase.errorDecoder
        , args =
            Encode.object
                [ Internal.clientIdField client
                , ( "collection", Encode.string collection )
                , ( "id", Encode.string id )
                ]
        }


{-| Request a password reset email for the given email address.

    PocketBase.Auth.requestPasswordReset client
        { collection = "users"
        , email = "user@example.com"
        }

-}
requestPasswordReset :
    Client
    -> { collection : String, email : String }
    -> ConcurrentTask Error ()
requestPasswordReset client { collection, email } =
    ConcurrentTask.define
        { function = "pocketbase:requestPasswordReset"
        , expect = ConcurrentTask.expectWhatever
        , errors = ConcurrentTask.expectErrors PocketBase.errorDecoder
        , args =
            Encode.object
                [ Internal.clientIdField client
                , ( "collection", Encode.string collection )
                , ( "email", Encode.string email )
                ]
        }


{-| Confirm a password reset using the token from the reset email.

    PocketBase.Auth.confirmPasswordReset client
        { collection = "users"
        , token = resetToken
        , password = "newSecret123"
        , passwordConfirm = "newSecret123"
        }

-}
confirmPasswordReset :
    Client
    -> { collection : String, token : String, password : String, passwordConfirm : String }
    -> ConcurrentTask Error ()
confirmPasswordReset client { collection, token, password, passwordConfirm } =
    ConcurrentTask.define
        { function = "pocketbase:confirmPasswordReset"
        , expect = ConcurrentTask.expectWhatever
        , errors = ConcurrentTask.expectErrors PocketBase.errorDecoder
        , args =
            Encode.object
                [ Internal.clientIdField client
                , ( "collection", Encode.string collection )
                , ( "token", Encode.string token )
                , ( "password", Encode.string password )
                , ( "passwordConfirm", Encode.string passwordConfirm )
                ]
        }
