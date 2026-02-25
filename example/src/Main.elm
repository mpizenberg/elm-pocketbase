port module Main exposing (main)

import Browser
import ConcurrentTask exposing (ConcurrentTask)
import Html exposing (Html, button, div, form, h1, h2, input, p, span, text)
import Html.Attributes exposing (class, disabled, placeholder, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Json.Decode as Decode
import Json.Encode as Encode
import PocketBase
import PocketBase.Auth
import PocketBase.Collection
import PocketBase.Realtime



-- PORTS


port send : Decode.Value -> Cmd msg


port receive : (Decode.Value -> msg) -> Sub msg


port onPocketbaseEvent : (Decode.Value -> msg) -> Sub msg



-- MODEL


type alias User =
    { id : String
    , email : String
    , name : String
    }


userDecoder : Decode.Decoder User
userDecoder =
    Decode.map3 User
        (Decode.field "id" Decode.string)
        (Decode.field "email" Decode.string)
        (Decode.field "name" Decode.string)


type alias Message =
    { id : String
    , text : String
    , created : String
    }


messageDecoder : Decode.Decoder Message
messageDecoder =
    Decode.map3 Message
        (Decode.field "id" Decode.string)
        (Decode.field "text" Decode.string)
        (Decode.field "created" Decode.string)


type alias Model =
    { tasks : ConcurrentTask.Pool Msg
    , client : Maybe PocketBase.Client
    , serverHealthy : Maybe Bool
    , authUser : Maybe User
    , loginIdentity : String
    , loginPassword : String
    , signupEmail : String
    , signupPassword : String
    , signupName : String
    , messages : List Message
    , newMessageText : String
    , errors : List String
    , realtimeEvents : List String
    }



-- MSG


type Msg
    = OnProgress ( ConcurrentTask.Pool Msg, Cmd Msg )
    | GotInit (ConcurrentTask.Response PocketBase.Error ( PocketBase.Client, Bool ))
    | GotLogin (ConcurrentTask.Response PocketBase.Error ( PocketBase.Client, User ))
    | GotSignup (ConcurrentTask.Response PocketBase.Error ( PocketBase.Client, User ))
    | GotLogout (ConcurrentTask.Response Never ())
    | GotMessages (ConcurrentTask.Response PocketBase.Error (PocketBase.Collection.ListResult Message))
    | GotCreated (ConcurrentTask.Response PocketBase.Error Message)
    | GotSubscribed (ConcurrentTask.Response Never ())
      -- UI
    | SetLoginIdentity String
    | SetLoginPassword String
    | SubmitLogin
    | SetSignupEmail String
    | SetSignupPassword String
    | SetSignupName String
    | SubmitSignup
    | SetNewMessage String
    | SubmitMessage
    | Logout
    | DismissError Int
    | OnRealtimeEvent Decode.Value



-- INIT


init : () -> ( Model, Cmd Msg )
init _ =
    let
        initTask =
            PocketBase.init "http://127.0.0.1:8090"
                |> ConcurrentTask.andThen
                    (\client ->
                        PocketBase.healthCheck client
                            |> ConcurrentTask.mapError never
                            |> ConcurrentTask.map (\healthy -> ( client, healthy ))
                    )

        ( tasks, cmd ) =
            ConcurrentTask.attempt
                { send = send
                , pool = ConcurrentTask.pool
                , onComplete = GotInit
                }
                initTask
    in
    ( { tasks = tasks
      , client = Nothing
      , serverHealthy = Nothing
      , authUser = Nothing
      , loginIdentity = ""
      , loginPassword = ""
      , signupEmail = ""
      , signupPassword = ""
      , signupName = ""
      , messages = []
      , newMessageText = ""
      , errors = []
      , realtimeEvents = []
      }
    , cmd
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OnProgress ( tasks, cmd ) ->
            ( { model | tasks = tasks }, cmd )

        GotInit response ->
            case response of
                ConcurrentTask.Success ( client, healthy ) ->
                    ( { model | client = Just client, serverHealthy = Just healthy }, Cmd.none )

                ConcurrentTask.Error err ->
                    ( { model | errors = errorToString err :: model.errors }, Cmd.none )

                ConcurrentTask.UnexpectedError ue ->
                    ( { model | errors = unexpectedErrorToString ue :: model.errors }, Cmd.none )

        GotLogin response ->
            case response of
                ConcurrentTask.Success ( client, user ) ->
                    let
                        fetchTask =
                            PocketBase.Collection.getList client
                                { collection = "messages"
                                , page = 1
                                , perPage = 50
                                , filter = Nothing
                                , sort = Just "-created"
                                , decoder = messageDecoder
                                }

                        subscribeTask =
                            PocketBase.Realtime.subscribe client "messages"

                        ( tasks, cmd ) =
                            model.tasks
                                |> attemptWith GotMessages fetchTask
                                |> attemptWith2 GotSubscribed subscribeTask
                    in
                    ( { model
                        | authUser = Just user
                        , loginPassword = ""
                        , tasks = tasks
                      }
                    , cmd
                    )

                ConcurrentTask.Error err ->
                    ( { model | errors = errorToString err :: model.errors }, Cmd.none )

                ConcurrentTask.UnexpectedError ue ->
                    ( { model | errors = unexpectedErrorToString ue :: model.errors }, Cmd.none )

        GotSignup response ->
            case response of
                ConcurrentTask.Success ( client, user ) ->
                    let
                        fetchTask =
                            PocketBase.Collection.getList client
                                { collection = "messages"
                                , page = 1
                                , perPage = 50
                                , filter = Nothing
                                , sort = Just "-created"
                                , decoder = messageDecoder
                                }

                        subscribeTask =
                            PocketBase.Realtime.subscribe client "messages"

                        ( tasks, cmd ) =
                            model.tasks
                                |> attemptWith GotMessages fetchTask
                                |> attemptWith2 GotSubscribed subscribeTask
                    in
                    ( { model
                        | authUser = Just user
                        , signupEmail = ""
                        , signupPassword = ""
                        , signupName = ""
                        , tasks = tasks
                      }
                    , cmd
                    )

                ConcurrentTask.Error err ->
                    ( { model | errors = errorToString err :: model.errors }, Cmd.none )

                ConcurrentTask.UnexpectedError ue ->
                    ( { model | errors = unexpectedErrorToString ue :: model.errors }, Cmd.none )

        GotLogout response ->
            case response of
                ConcurrentTask.Success () ->
                    ( { model
                        | authUser = Nothing
                        , messages = []
                        , realtimeEvents = []
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        GotMessages response ->
            case response of
                ConcurrentTask.Success result ->
                    ( { model | messages = result.items }, Cmd.none )

                ConcurrentTask.Error err ->
                    ( { model | errors = errorToString err :: model.errors }, Cmd.none )

                ConcurrentTask.UnexpectedError ue ->
                    ( { model | errors = unexpectedErrorToString ue :: model.errors }, Cmd.none )

        GotCreated response ->
            case response of
                ConcurrentTask.Success message ->
                    ( { model
                        | messages = message :: model.messages
                        , newMessageText = ""
                      }
                    , Cmd.none
                    )

                ConcurrentTask.Error err ->
                    ( { model | errors = errorToString err :: model.errors }, Cmd.none )

                ConcurrentTask.UnexpectedError ue ->
                    ( { model | errors = unexpectedErrorToString ue :: model.errors }, Cmd.none )

        GotSubscribed _ ->
            ( model, Cmd.none )

        SetLoginIdentity val ->
            ( { model | loginIdentity = val }, Cmd.none )

        SetLoginPassword val ->
            ( { model | loginPassword = val }, Cmd.none )

        SetSignupEmail val ->
            ( { model | signupEmail = val }, Cmd.none )

        SetSignupPassword val ->
            ( { model | signupPassword = val }, Cmd.none )

        SetSignupName val ->
            ( { model | signupName = val }, Cmd.none )

        SubmitSignup ->
            case model.client of
                Just client ->
                    let
                        signupTask =
                            PocketBase.Auth.createAccount client
                                { collection = "users"
                                , body =
                                    Encode.object
                                        [ ( "email", Encode.string model.signupEmail )
                                        , ( "password", Encode.string model.signupPassword )
                                        , ( "passwordConfirm", Encode.string model.signupPassword )
                                        , ( "name", Encode.string model.signupName )
                                        ]
                                , decoder = Decode.succeed ()
                                }
                                |> ConcurrentTask.andThen
                                    (\_ ->
                                        PocketBase.Auth.authWithPassword client
                                            { collection = "users"
                                            , identity = model.signupEmail
                                            , password = model.signupPassword
                                            , decoder = userDecoder
                                            }
                                    )
                                |> ConcurrentTask.map (\user -> ( client, user ))

                        ( tasks, cmd ) =
                            attemptWith GotSignup signupTask model.tasks
                    in
                    ( { model | tasks = tasks }, cmd )

                Nothing ->
                    ( { model | errors = "Client not initialized" :: model.errors }, Cmd.none )

        SubmitLogin ->
            case model.client of
                Just client ->
                    let
                        loginTask =
                            PocketBase.Auth.authWithPassword client
                                { collection = "users"
                                , identity = model.loginIdentity
                                , password = model.loginPassword
                                , decoder = userDecoder
                                }
                                |> ConcurrentTask.map (\user -> ( client, user ))

                        ( tasks, cmd ) =
                            attemptWith GotLogin loginTask model.tasks
                    in
                    ( { model | tasks = tasks }, cmd )

                Nothing ->
                    ( { model | errors = "Client not initialized" :: model.errors }, Cmd.none )

        Logout ->
            case model.client of
                Just client ->
                    let
                        logoutTask =
                            PocketBase.Realtime.unsubscribeAll client
                                |> ConcurrentTask.andThenDo (PocketBase.Auth.logout client)

                        ( tasks, cmd ) =
                            attemptWith GotLogout logoutTask model.tasks
                    in
                    ( { model | tasks = tasks }, cmd )

                Nothing ->
                    ( model, Cmd.none )

        SetNewMessage val ->
            ( { model | newMessageText = val }, Cmd.none )

        SubmitMessage ->
            case model.client of
                Just client ->
                    let
                        createTask =
                            PocketBase.Collection.create client
                                { collection = "messages"
                                , body =
                                    Encode.object
                                        [ ( "text", Encode.string model.newMessageText )
                                        ]
                                , decoder = messageDecoder
                                }

                        ( tasks, cmd ) =
                            attemptWith GotCreated createTask model.tasks
                    in
                    ( { model | tasks = tasks }, cmd )

                Nothing ->
                    ( model, Cmd.none )

        DismissError idx ->
            ( { model | errors = removeAt idx model.errors }, Cmd.none )

        OnRealtimeEvent val ->
            case Decode.decodeValue PocketBase.Realtime.decodeEvent val of
                Ok ( collection, event ) ->
                    let
                        eventStr =
                            collection ++ ": " ++ describeEvent event
                    in
                    ( { model | realtimeEvents = eventStr :: model.realtimeEvents }, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )


attemptWith :
    (ConcurrentTask.Response x a -> Msg)
    -> ConcurrentTask x a
    -> ConcurrentTask.Pool Msg
    -> ( ConcurrentTask.Pool Msg, Cmd Msg )
attemptWith onComplete task pool =
    ConcurrentTask.attempt
        { send = send
        , pool = pool
        , onComplete = onComplete
        }
        task


attemptWith2 :
    (ConcurrentTask.Response x a -> Msg)
    -> ConcurrentTask x a
    -> ( ConcurrentTask.Pool Msg, Cmd Msg )
    -> ( ConcurrentTask.Pool Msg, Cmd Msg )
attemptWith2 onComplete task ( pool, prevCmd ) =
    let
        ( newPool, cmd ) =
            attemptWith onComplete task pool
    in
    ( newPool, Cmd.batch [ prevCmd, cmd ] )



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ h1 [] [ text "elm-pocketbase example" ]
        , viewErrors model.errors
        , viewStatus model.serverHealthy
        , case model.authUser of
            Nothing ->
                viewLoginForm model

            Just user ->
                viewApp model user
        ]


viewStatus : Maybe Bool -> Html Msg
viewStatus maybeHealthy =
    div []
        [ text "Server: "
        , case maybeHealthy of
            Nothing ->
                span [ class "status warn" ] [ text "connecting..." ]

            Just True ->
                span [ class "status ok" ] [ text "healthy" ]

            Just False ->
                span [ class "status err" ] [ text "unreachable" ]
        ]


viewErrors : List String -> Html Msg
viewErrors errors =
    if List.isEmpty errors then
        text ""

    else
        div [] (List.indexedMap viewError errors)


viewError : Int -> String -> Html Msg
viewError idx err =
    div [ class "error" ]
        [ text err
        , text " "
        , button [ onClick (DismissError idx) ] [ text "x" ]
        ]


viewLoginForm : Model -> Html Msg
viewLoginForm model =
    div []
        [ h2 [] [ text "Login" ]
        , form [ onSubmit SubmitLogin ]
            [ input [ placeholder "email or username", value model.loginIdentity, onInput SetLoginIdentity ] []
            , input [ type_ "password", placeholder "password", value model.loginPassword, onInput SetLoginPassword ] []
            , button [ type_ "submit", disabled (model.client == Nothing) ] [ text "Log in" ]
            ]
        , h2 [] [ text "Create account" ]
        , form [ onSubmit SubmitSignup ]
            [ input [ placeholder "name", value model.signupName, onInput SetSignupName ] []
            , input [ placeholder "email", value model.signupEmail, onInput SetSignupEmail ] []
            , input [ type_ "password", placeholder "password", value model.signupPassword, onInput SetSignupPassword ] []
            , button [ type_ "submit", disabled (model.client == Nothing) ] [ text "Sign up" ]
            ]
        ]


viewApp : Model -> User -> Html Msg
viewApp model user =
    div []
        [ div []
            [ text ("Logged in as " ++ user.name ++ " ")
            , button [ onClick Logout ] [ text "Logout" ]
            ]
        , h2 [] [ text "New message" ]
        , form [ onSubmit SubmitMessage ]
            [ input [ placeholder "Type a message...", value model.newMessageText, onInput SetNewMessage ] []
            , button [ type_ "submit", disabled (String.isEmpty model.newMessageText) ] [ text "Send" ]
            ]
        , h2 [] [ text "Messages" ]
        , if List.isEmpty model.messages then
            p [] [ text "No messages yet." ]

          else
            div [] (List.map viewMessage model.messages)
        , h2 [] [ text "Realtime events" ]
        , if List.isEmpty model.realtimeEvents then
            p [] [ text "Waiting for events..." ]

          else
            div [] (List.map (\e -> div [ class "event" ] [ text e ]) model.realtimeEvents)
        ]


viewMessage : Message -> Html Msg
viewMessage message =
    div [ class "msg" ]
        [ text message.text
        , text " "
        , span [ class "status" ] [ text message.created ]
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ ConcurrentTask.onProgress
            { send = send
            , receive = receive
            , onProgress = OnProgress
            }
            model.tasks
        , onPocketbaseEvent OnRealtimeEvent
        ]



-- HELPERS


errorToString : PocketBase.Error -> String
errorToString err =
    case err of
        PocketBase.NotFound ->
            "Not found"

        PocketBase.Unauthorized ->
            "Unauthorized"

        PocketBase.Forbidden ->
            "Forbidden"

        PocketBase.BadRequest msg ->
            "Bad request: " ++ msg

        PocketBase.Conflict ->
            "Conflict"

        PocketBase.TooManyRequests ->
            "Too many requests"

        PocketBase.ServerError msg ->
            "Server error: " ++ msg

        PocketBase.NetworkError msg ->
            "Network error: " ++ msg


unexpectedErrorToString : ConcurrentTask.UnexpectedError -> String
unexpectedErrorToString err =
    case err of
        ConcurrentTask.UnhandledJsException { function, message } ->
            "JS exception in " ++ function ++ ": " ++ message

        ConcurrentTask.ResponseDecoderFailure { function, error } ->
            "Decoder failure in " ++ function ++ ": " ++ Decode.errorToString error

        ConcurrentTask.ErrorsDecoderFailure { function, error } ->
            "Error decoder failure in " ++ function ++ ": " ++ Decode.errorToString error

        ConcurrentTask.MissingFunction name ->
            "Missing function: " ++ name

        ConcurrentTask.InternalError msg ->
            "Internal error: " ++ msg


describeEvent : PocketBase.Realtime.SubscriptionEvent -> String
describeEvent event =
    case event of
        PocketBase.Realtime.Created _ ->
            "created"

        PocketBase.Realtime.Updated _ ->
            "updated"

        PocketBase.Realtime.Deleted _ ->
            "deleted"


removeAt : Int -> List a -> List a
removeAt idx list =
    List.take idx list ++ List.drop (idx + 1) list



-- MAIN


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
