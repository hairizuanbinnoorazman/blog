module BMICalculator exposing (..)

import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Browser
import FormatNumber
import FormatNumber.Locales as Locales
import Html exposing (Html, button, div, h2, p, text)
import Html.Attributes exposing (for, style)
import Html.Events exposing (onClick)


main : Program () Model Msg
main =
    Browser.element
        { view = view
        , init = \() -> init
        , update = update
        , subscriptions = subscriptions
        }


type alias BMICalculatorState =
    { height : Float
    , weight : Float
    , bmi : Float
    }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


type alias Model =
    { value : Int
    , bmiCalculator : BMICalculatorState
    }


init : ( Model, Cmd Msg )
init =
    ( Model 0 (BMICalculatorState 0 0 0), Cmd.none )


type Msg
    = BMICalculatorWeightInput String
    | BMICalculatorHeightInput String


view : Model -> Html Msg
view model =
    div []
        [ bmiCalculatorPage model
        ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        BMICalculatorWeightInput weightInput ->
            ( { model | bmiCalculator = BMICalculatorState model.bmiCalculator.height (Maybe.withDefault 0 (String.toFloat weightInput)) (Maybe.withDefault 0 (String.toFloat weightInput) / model.bmiCalculator.height ^ 2) }, Cmd.none )

        BMICalculatorHeightInput heightInput ->
            ( { model | bmiCalculator = BMICalculatorState (Maybe.withDefault 0 (String.toFloat heightInput)) model.bmiCalculator.weight (model.bmiCalculator.weight / Maybe.withDefault 0 (String.toFloat heightInput) ^ 2) }, Cmd.none )


bmiCalculatorPage : Model -> Html Msg
bmiCalculatorPage model =
    div []
        [ div []
            [ Form.form []
                [ Form.group []
                    [ Form.label [ for "height" ] [ text "Height in m" ]
                    , Input.number [ Input.id "height", Input.value (String.fromFloat model.bmiCalculator.height), Input.onInput BMICalculatorHeightInput ]
                    ]
                , Form.group []
                    [ Form.label [ for "weight" ] [ text "Weight in kg" ]
                    , Input.number [ Input.id "weight", Input.value (String.fromFloat model.bmiCalculator.weight), Input.onInput BMICalculatorWeightInput ]
                    ]
                ]
            ]
        , if model.bmiCalculator.weight < 20 || model.bmiCalculator.weight > 350 then
            div []
                [ p [ style "color" "red" ] [ text "Invalid weight passed in" ]
                ]

          else if model.bmiCalculator.height < 0.8 || model.bmiCalculator.height > 2.5 then
            div []
                [ p [ style "color" "red" ] [ text "Invalid height passed in" ]
                ]

          else if model.bmiCalculator.bmi < 18.5 then
            div []
                [ p [ style "color" "orange" ] [ text ("Underweight - BMI is " ++ FormatNumber.format Locales.usLocale model.bmiCalculator.bmi) ]
                , p [] [ text ("An ideal weight range for someone of your height is " ++ FormatNumber.format Locales.usLocale (18.5 * model.bmiCalculator.height ^ 2) ++ "kg to " ++ FormatNumber.format Locales.usLocale (23 * model.bmiCalculator.height ^ 2) ++ "kg.") ]
                ]

          else if model.bmiCalculator.bmi >= 18.5 && model.bmiCalculator.bmi < 23 then
            div []
                [ p [ style "color" "green" ] [ text ("Healthy - BMI is " ++ FormatNumber.format Locales.usLocale model.bmiCalculator.bmi) ]
                , p [] [ text ("You are in the ideal weight range for someone of your height. You should keep your weight between " ++ FormatNumber.format Locales.usLocale (18.5 * model.bmiCalculator.height ^ 2) ++ "kg and " ++ FormatNumber.format Locales.usLocale (23 * model.bmiCalculator.height ^ 2) ++ "kg.") ]
                ]

          else if model.bmiCalculator.bmi >= 23 && model.bmiCalculator.bmi < 27.5 then
            div []
                [ p [ style "color" "orange" ] [ text ("Overweight - BMI is " ++ FormatNumber.format Locales.usLocale model.bmiCalculator.bmi) ]
                , p [] [ text ("An ideal weight range for someone of your height is " ++ FormatNumber.format Locales.usLocale (18.5 * model.bmiCalculator.height ^ 2) ++ "kg to " ++ FormatNumber.format Locales.usLocale (23 * model.bmiCalculator.height ^ 2) ++ "kg.") ]
                ]

          else if model.bmiCalculator.bmi >= 27.5 && model.bmiCalculator.bmi < 150 then
            div []
                [ p [ style "color" "red" ] [ text ("Obese - BMI is " ++ FormatNumber.format Locales.usLocale model.bmiCalculator.bmi) ]
                , p [] [ text ("An ideal weight range for someone of your height is " ++ FormatNumber.format Locales.usLocale (18.5 * model.bmiCalculator.height ^ 2) ++ "kg to " ++ FormatNumber.format Locales.usLocale (23 * model.bmiCalculator.height ^ 2) ++ "kg.") ]
                ]

          else
            div []
                [ p [ style "color" "red" ] [ text "Invalid BMI value" ]
                ]
        ]
