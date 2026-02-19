module PocketBase.Collection exposing (getOne, getList, create, ListResult)

{-| PocketBase collection CRUD operations.

@docs getOne, getList, create, ListResult

-}

import ConcurrentTask exposing (ConcurrentTask)
import Json.Decode as Decode
import Json.Encode as Encode
import PocketBase exposing (Client, Error)
import PocketBase.Internal as Internal


{-| Paginated list result from PocketBase.
-}
type alias ListResult a =
    { page : Int
    , perPage : Int
    , totalItems : Int
    , totalPages : Int
    , items : List a
    }


{-| Fetch a single record by ID.

    PocketBase.Collection.getOne client
        { collection = "groups"
        , id = groupId
        , decoder = groupDecoder
        }

-}
getOne :
    Client
    -> { collection : String, id : String, decoder : Decode.Decoder a }
    -> ConcurrentTask Error a
getOne client { collection, id, decoder } =
    ConcurrentTask.define
        { function = "pocketbase:getOne"
        , expect = ConcurrentTask.expectJson decoder
        , errors = ConcurrentTask.expectErrors PocketBase.errorDecoder
        , args =
            Encode.object
                [ Internal.clientIdField client
                , ( "collection", Encode.string collection )
                , ( "id", Encode.string id )
                ]
        }


{-| Fetch a paginated list of records with optional filter and sort.

    PocketBase.Collection.getList client
        { collection = "loro_updates"
        , page = 1
        , perPage = 1000
        , filter = Just ("groupId=\"" ++ groupId ++ "\" && timestamp > " ++ String.fromInt since)
        , sort = Just "+timestamp"
        , decoder = loroUpdateDecoder
        }

-}
getList :
    Client
    ->
        { collection : String
        , page : Int
        , perPage : Int
        , filter : Maybe String
        , sort : Maybe String
        , decoder : Decode.Decoder a
        }
    -> ConcurrentTask Error (ListResult a)
getList client { collection, page, perPage, filter, sort, decoder } =
    ConcurrentTask.define
        { function = "pocketbase:getList"
        , expect = ConcurrentTask.expectJson (listResultDecoder decoder)
        , errors = ConcurrentTask.expectErrors PocketBase.errorDecoder
        , args =
            Encode.object
                [ Internal.clientIdField client
                , ( "collection", Encode.string collection )
                , ( "page", Encode.int page )
                , ( "perPage", Encode.int perPage )
                , ( "filter", encodeMaybe Encode.string filter )
                , ( "sort", encodeMaybe Encode.string sort )
                ]
        }


{-| Create a new record.

    PocketBase.Collection.create client
        { collection = "loro_updates"
        , body = encodeLoroUpdate update
        , decoder = loroUpdateDecoder
        }

-}
create :
    Client
    -> { collection : String, body : Encode.Value, decoder : Decode.Decoder a }
    -> ConcurrentTask Error a
create client { collection, body, decoder } =
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


listResultDecoder : Decode.Decoder a -> Decode.Decoder (ListResult a)
listResultDecoder itemDecoder =
    Decode.map5 ListResult
        (Decode.field "page" Decode.int)
        (Decode.field "perPage" Decode.int)
        (Decode.field "totalItems" Decode.int)
        (Decode.field "totalPages" Decode.int)
        (Decode.field "items" (Decode.list itemDecoder))


encodeMaybe : (a -> Encode.Value) -> Maybe a -> Encode.Value
encodeMaybe encoder maybe =
    case maybe of
        Just value ->
            encoder value

        Nothing ->
            Encode.null
