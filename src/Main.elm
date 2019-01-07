port module Main exposing (main)

import Browser
import Html exposing (..)
import Json.Decode as Decode exposing (decodeValue)
import Json.Encode as Encode exposing (encode)
import Json.Encode.Extra as EncodeExtra


main =
    Browser.document
        { init = init
        , view = \_ -> { title = "Battleships", body = [ h1 [] [ text "Battleships" ] ] }
        , update = update
        , subscriptions =
            \_ ->
                Sub.batch
                    [ receiveActorMessage ReceivedIncomingActorMessage
                        (Debug.log "Error while receiving a message" >> FailedToParseIncomingActorMessage)
                    ]
        }


port outgoingActorMessages : GenericActorMessage -> Cmd msg


port incomingActorMessages : (GenericActorMessage -> msg) -> Sub msg


type alias GenericActorMessage =
    { tag : String
    , data : Encode.Value
    }


type OutgoingActorMessage
    = ConnectToServer (Maybe String)
    | ConnectToPeer String
    | SendPayload Payload


type IncomingActorMessage
    = ConnectedToServer String
    | ConnectedToPeer -- TODO: Accept a String
    | ReceivedPayload Payload


type Payload
    = Message String


sendActorMessage : OutgoingActorMessage -> Cmd msg
sendActorMessage message =
    case message of
        ConnectToServer maybeId ->
            outgoingActorMessages
                { tag = "ConnectToServer"
                , data = EncodeExtra.maybe Encode.string maybeId
                }

        ConnectToPeer id ->
            outgoingActorMessages
                { tag = "ConnectToPeer"
                , data = Encode.string id
                }

        SendPayload payload ->
            outgoingActorMessages
                { tag = "SendPayload"
                , data = encodePayload payload
                }


receiveActorMessage : (IncomingActorMessage -> msg) -> (String -> msg) -> Sub msg
receiveActorMessage tagger onError =
    incomingActorMessages
        (\genericMessage ->
            case genericMessage.tag of
                "ConnectedToServer" ->
                    case decodeValue Decode.string genericMessage.data of
                        Ok id ->
                            tagger <| ConnectedToServer id

                        Err error ->
                            onError <| Decode.errorToString error

                "ConnectedToPeer" ->
                    tagger <| ConnectedToPeer

                "ReceivedPayload" ->
                    case decodeValue payloadDecoder genericMessage.data of
                        Ok payload ->
                            tagger <| ReceivedPayload payload

                        Err error ->
                            onError <| Decode.errorToString error

                _ ->
                    -- TODO: Pass the whole genericMessage to onError.
                    onError <| "Unexpected info from outside: " ++ genericMessage.tag
        )


encodePayload : Payload -> Encode.Value
encodePayload payload =
    case payload of
        Message message ->
            Encode.object
                [ ( "type", Encode.string "Message" )
                , ( "payload", Encode.string message )
                ]


payloadDecoder : Decode.Decoder Payload
payloadDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\payloadType ->
                case payloadType of
                    "Message" ->
                        Decode.field "payload" Decode.string |> Decode.map Message

                    _ ->
                        Decode.fail <| "Unknown payload type " ++ payloadType
            )


type alias Flags =
    { connectTo : Maybe String
    , connectAs : Maybe String
    }


type alias Model =
    { connectTo : Maybe String

    -- TODO: Change it to some kind of a custom type signifying the status of the connection.
    , connectedAs : Maybe String
    }


type Msg
    = ReceivedIncomingActorMessage IncomingActorMessage
    | FailedToParseIncomingActorMessage String


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { connectTo = flags.connectTo, connectedAs = Nothing }
    , sendActorMessage <| ConnectToServer flags.connectAs
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ReceivedIncomingActorMessage incomingActorMessage ->
            case incomingActorMessage of
                ConnectedToServer id ->
                    ( { model | connectedAs = Just id }
                    , model.connectTo
                        |> Maybe.map (sendActorMessage << ConnectToPeer)
                        |> Maybe.withDefault Cmd.none
                    )

                ConnectedToPeer ->
                    ( model
                    , model.connectedAs
                        |> Maybe.map (sendActorMessage << SendPayload << Message << (++) "Hello from ")
                        |> Maybe.withDefault Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        _ ->
            ( model, Cmd.none )
