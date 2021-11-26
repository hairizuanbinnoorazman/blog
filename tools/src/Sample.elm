module Sample exposing (Model, Msg(..), init, main, subscriptions, update, view)

import Browser
import Html exposing (Html, button, div, p, text)
import Html.Events exposing (onClick)


main : Program () Model Msg
main =
    Browser.element
        { view = view
        , init = \() -> init
        , update = update
        , subscriptions = subscriptions
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


type alias Model =
    { value : Int
    }


init : ( Model, Cmd Msg )
init =
    ( Model 0, Cmd.none )


type Msg
    = Increment
    | Decrement


view : Model -> Html Msg
view model =
    div []
        [ p [] [ text ("Value: " ++ String.fromInt model.value) ]
        , button [ onClick Increment ] [ text "+" ]
        , button [ onClick Decrement ] [ text "-" ]
        ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Increment ->
            ( { model | value = model.value + 1 }, Cmd.none )

        Decrement ->
            ( { model | value = model.value - 1 }, Cmd.none )
