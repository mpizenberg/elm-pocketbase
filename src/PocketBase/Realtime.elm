module PocketBase.Realtime exposing (subscribe, unsubscribe, unsubscribeAll, SubscriptionEvent(..), decodeEvent)

{-| Real-time SSE subscriptions for PocketBase collections.

Subscribe/unsubscribe are tasks that set up the JS-side listener.
Actual events arrive through a port that the consuming app defines:

    port onPocketbaseEvent : (Decode.Value -> msg) -> Sub msg

Use `decodeEvent` to parse incoming events.

@docs subscribe, unsubscribe, unsubscribeAll, SubscriptionEvent, decodeEvent

-}

import ConcurrentTask exposing (ConcurrentTask)
import Json.Decode as Decode
import Json.Encode as Encode
import PocketBase exposing (Client)
import PocketBase.Internal as Internal


{-| A real-time subscription event from PocketBase.
-}
type SubscriptionEvent
    = Created Decode.Value
    | Updated Decode.Value
    | Deleted Decode.Value


{-| Subscribe to all changes on a collection.
The JS companion calls `pb.collection(name).subscribe('*', callback)`.
Events arrive through the `onPocketbaseEvent` subscription port.
-}
subscribe : Client -> String -> ConcurrentTask Never ()
subscribe client collection =
    ConcurrentTask.define
        { function = "pocketbase:subscribe"
        , expect = ConcurrentTask.expectWhatever
        , errors = ConcurrentTask.expectNoErrors
        , args =
            Encode.object
                [ Internal.clientIdField client
                , ( "collection", Encode.string collection )
                ]
        }


{-| Unsubscribe from a collection.
-}
unsubscribe : Client -> String -> ConcurrentTask Never ()
unsubscribe client collection =
    ConcurrentTask.define
        { function = "pocketbase:unsubscribe"
        , expect = ConcurrentTask.expectWhatever
        , errors = ConcurrentTask.expectNoErrors
        , args =
            Encode.object
                [ Internal.clientIdField client
                , ( "collection", Encode.string collection )
                ]
        }


{-| Unsubscribe from all collections.
-}
unsubscribeAll : Client -> ConcurrentTask Never ()
unsubscribeAll client =
    ConcurrentTask.define
        { function = "pocketbase:unsubscribeAll"
        , expect = ConcurrentTask.expectWhatever
        , errors = ConcurrentTask.expectNoErrors
        , args = Encode.object [ Internal.clientIdField client ]
        }


{-| Decode an incoming real-time event.
Returns a tuple of (collection name, event).
-}
decodeEvent : Decode.Decoder ( String, SubscriptionEvent )
decodeEvent =
    Decode.map2 Tuple.pair
        (Decode.field "collection" Decode.string)
        (Decode.field "action" Decode.string
            |> Decode.andThen
                (\action ->
                    let
                        record =
                            Decode.field "record" Decode.value
                    in
                    case action of
                        "create" ->
                            Decode.map Created record

                        "update" ->
                            Decode.map Updated record

                        "delete" ->
                            Decode.map Deleted record

                        _ ->
                            Decode.fail ("Unknown action: " ++ action)
                )
        )
