module Main exposing (main)

import Browser
import Html exposing (..)


main =
    Browser.document
        { init = init
        , view = \_ -> { title = "Battleships", body = [ h1 [] [ text "Battleships" ] ] }
        , update = \_ model -> ( model, Cmd.none )
        , subscriptions = \_ -> Sub.none
        }


init : () -> ( (), Cmd msg )
init _ =
    ( (), Cmd.none )
