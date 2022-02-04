port module BusArrival exposing (..)

import Browser
import Html exposing (Html, button, div, h3, input, p, table, td, text, th, tr)
import Html.Attributes exposing (placeholder, style, value)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode as Decode exposing (Decoder, decodeString, int, list, string)
import Json.Decode.Pipeline as Pipeline


main : Program Flags Model Msg
main =
    Browser.element
        { view = view
        , init = init
        , update = update
        , subscriptions = subscriptions
        }


init : Flags -> ( Model, Cmd Msg )
init flags =
    if flags.busStopIDs == "" then
        ( Model "" (List.map initBusArrival []), Cmd.none )
    else
        ( Model "" (List.map initBusArrival (String.split "," flags.busStopIDs)), Cmd.none )


initBusArrival : String -> BusArrivals
initBusArrival busStopID =
    BusArrivals busStopID []



-- main : Program () Model Msg
-- main =
--     Browser.element
--         { view = view
--         , init = \() -> init
--         , update = update
--         , subscriptions = subscriptions
--         }
-- init : ( Model, Cmd Msg )
-- init =
--     ( Model "" [], Cmd.none )


port storeBusStopID : String -> Cmd msg


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


type alias Flags =
    { busStopIDs : String
    }


type alias Model =
    { newBusStopID : String
    , busArrivalData : List BusArrivals
    }


type Msg
    = UpdateBusStopID String
    | RefreshBusArrival String
    | GetBusArrivals (Result Http.Error BusArrivals)
    | AddBusStop
    | RemoveBusStop String


view : Model -> Html Msg
view model =
    div []
        [ input [ style "height" "50px", placeholder "Bus Stop ID", value model.newBusStopID, onInput UpdateBusStopID ] []
        , button [ style "height" "50px", style "width" "100px", onClick AddBusStop ] [ text "Add Bus Stop" ]
        , div [] (List.map busArrivalsView model.busArrivalData)
        ]


getBusStopID : BusArrivals -> String
getBusStopID busArrivals =
    busArrivals.busStopID


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        RemoveBusStop busStopID ->
            let
                temp =
                    List.filter (filterOutBusArrivalData busStopID) model.busArrivalData

                tempString =
                    List.map getBusStopID temp

                storeValue =
                    String.join "," tempString
            in
            ( { model | busArrivalData = temp }, Cmd.batch [ storeBusStopID storeValue ] )

        UpdateBusStopID busStopID ->
            ( { model | newBusStopID = busStopID }, Cmd.none )

        AddBusStop ->
            let
                tempBusStopID =
                    model.newBusStopID

                tempBusArrivalData =
                    List.append model.busArrivalData [ BusArrivals model.newBusStopID [] ]

                temp =
                    List.map getBusStopID tempBusArrivalData

                storeValue =
                    String.join "," temp
            in
            ( { model | busArrivalData = tempBusArrivalData, newBusStopID = "" }, Cmd.batch [ apiGetBusArrivals tempBusStopID, storeBusStopID storeValue ] )

        RefreshBusArrival busStopID ->
            ( model, Cmd.batch [ apiGetBusArrivals busStopID ] )

        GetBusArrivals result ->
            case result of
                Ok a ->
                    let
                        temp =
                            List.map (updateBusArrivalData a) model.busArrivalData
                    in
                    ( { model | busArrivalData = temp }, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )


filterOutBusArrivalData : String -> BusArrivals -> Bool
filterOutBusArrivalData busStopID busArrival =
    if busArrival.busStopID == busStopID then
        False

    else
        True


updateBusArrivalData : BusArrivals -> BusArrivals -> BusArrivals
updateBusArrivalData newBusArrivals currentBusArrival =
    if currentBusArrival.busStopID == newBusArrivals.busStopID then
        newBusArrivals

    else
        currentBusArrival


busArrivalsView : BusArrivals -> Html Msg
busArrivalsView busArrivals =
    div []
        [ h3 [] [ text busArrivals.busStopID ]
        , button [ style "height" "50px", onClick (RefreshBusArrival busArrivals.busStopID) ] [ text "Refresh" ]
        , button [ style "height" "50px", onClick (RemoveBusStop busArrivals.busStopID) ] [ text "Remove" ]
        , table [ style "width" "100%", style "border" "1px solid black", style "border-collapse" "collapse" ]
            (List.concat
                [ [ tr []
                        [ th [ style "border" "1px solid black" ] [ text "Bus Service" ]
                        , th [ style "border" "1px solid black" ] [ text "Next Bus (mins)" ]
                        , th [ style "border" "1px solid black" ] [ text "Next Bus 2 (mins)" ]
                        , th [ style "border" "1px solid black" ] [ text "Next Bus 3 (mins)" ]
                        ]
                  ]
                , List.map busServiceView busArrivals.services
                ]
            )
        ]


busServiceView : SingleBusService -> Html Msg
busServiceView singleBusService =
    tr []
        [ td [ style "border" "1px solid black" ] [ text singleBusService.serviceNo ]
        , td [ style "border" "1px solid black" ] [ text (String.fromInt singleBusService.nextBus) ]
        , td [ style "border" "1px solid black" ] [ text (String.fromInt singleBusService.nextBus2) ]
        , td [ style "border" "1px solid black" ] [ text (String.fromInt singleBusService.nextBus3) ]
        ]


type alias BusArrivals =
    { busStopID : String
    , services : List SingleBusService
    }


busArrivalsDecoder : Decoder BusArrivals
busArrivalsDecoder =
    Decode.succeed BusArrivals
        |> Pipeline.required "bus_stop_id" string
        |> Pipeline.required "services" (list singleBusServiceDecoder)


type alias SingleBusService =
    { serviceNo : String
    , nextBus : Int
    , nextBus2 : Int
    , nextBus3 : Int
    }


singleBusServiceDecoder : Decoder SingleBusService
singleBusServiceDecoder =
    Decode.succeed SingleBusService
        |> Pipeline.required "service_no" string
        |> Pipeline.required "next_bus" int
        |> Pipeline.required "next_bus_2" int
        |> Pipeline.required "next_bus_3" int


apiGetBusArrivals : String -> Cmd Msg
apiGetBusArrivals busStopID =
    let
        url =
            "/api/lta-datamall/v1/bus-arrival?bus-stop-id=" ++ busStopID
    in
    Http.request
        { body = Http.emptyBody
        , method = "GET"
        , url = url
        , headers = []
        , timeout = Nothing
        , tracker = Nothing
        , expect = Http.expectJson GetBusArrivals busArrivalsDecoder
        }
