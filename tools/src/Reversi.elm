module Reversi exposing (..)

import Browser
import Html exposing (Html, button, div, p, text)
import Html.Attributes exposing (style)
import Html.Events exposing (onClick)
import Array2D


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
    { cellState : List (List CellState)
    , whiteScore : Int
    , blackScore : Int
    }


type CellState
    = Empty
    | PotentialWhite
    | PotentialBlack
    | Black
    | White


init : ( Model, Cmd Msg )
init =
    let
        emptyRow =
            List.repeat 8  Empty

        whiteFirst =
            (List.repeat 3 Empty) ++ [White, Black] ++ (List.repeat 3 Empty)

        blackFirst =
            (List.repeat 3 Empty) ++ [Black, White] ++ (List.repeat 3 Empty)
    in
    ( Model [ emptyRow, emptyRow, emptyRow, whiteFirst, blackFirst, emptyRow, emptyRow, emptyRow ] 0 0, Cmd.none )


type Msg
    = Increment
    | Decrement
    

possiblePlay : CellState -> Array2D.Array2D CellState -> CellState
possiblePlay playerCellState currentGrid = 
    Empty


renderCell : CellState -> Html Msg
renderCell cellState =
    let
        standardCell =
            [ style "display" "flex", style "height" "50px", style "width" "50px", style "background" "green", style "border" "solid 1px black", style "justify-content" "center", style "align-items" "center" ]
    in
    case cellState of
        Empty ->
            div standardCell []

        PotentialBlack ->
            div standardCell
                [ div [ style "opacity" "20%", style "height" "90%", style "width" "90%", style "border-radius" "50%", style "background" "black" ] []
                ]

        PotentialWhite ->
            div standardCell
                [ div [ style "opacity" "20%", style "height" "90%", style "width" "90%", style "border-radius" "50%", style "background" "white" ] []
                ]

        White ->
            div standardCell
                [ div [ style "height" "90%", style "width" "90%", style "border-radius" "50%", style "background" "white" ] []
                ]

        Black ->
            div standardCell
                [ div [ style "height" "90%", style "width" "90%", style "border-radius" "50%", style "background" "black" ] []
                ]


renderRow : List CellState -> Html Msg
renderRow rowCellState =
    div [ style "display" "flex", style "height" "52px", style "border" "0px", style "margin" "0px", style "padding" "0px", style "flex-direction" "row" ] (List.map renderCell rowCellState)


renderGrid : List (List CellState) -> Html Msg
renderGrid gridCellState =
    div [] (List.map renderRow gridCellState)


view : Model -> Html Msg
view model =
    div [ style "display" "flex", style "flex-direction" "column" ]
        [ renderGrid model.cellState
        ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Increment ->
            ( model, Cmd.none )

        Decrement ->
            ( model, Cmd.none )
