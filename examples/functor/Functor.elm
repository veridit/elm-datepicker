module Simple exposing (main)

import Date exposing (Date, Day(..), day, dayOfWeek, month, year)
import DatePicker exposing (defaultSettings)
import Html exposing (Html, div, h1, text)


type Msg
    = DatePickerMsg DatePicker.Msg


type alias Model =
    { date : DatePicker.Model
    , datePicker : DatePicker.UiState
    }


-- type alias CustomDatePicker a = {a | }
datePicker :
    { init : ( DatePicker.UiState, Cmd DatePicker.Msg )
    , update : DatePicker.Msg
        -> ( { a | date : DatePicker.Model, datePicker : DatePicker.UiState }, Cmd Msg)
        -> ( { a | date : DatePicker.Model, datePicker : DatePicker.UiState }, Cmd Msg)
    , view :{ b | date : DatePicker.Model, datePicker : DatePicker.UiState } -> Html Msg
    }
datePicker =
    let
        settings = DatePicker.defaultSettings
        customSettings = 
            let
                isDisabled date =
                    dayOfWeek date
                        |> flip List.member [ Sat, Sun ]
            in
                { settings | isDisabled = isDisabled }
    in
    { init = DatePicker.init
        {-
        -- Record extension is required to allow
      init =
        \maybeDate (outerModel, outerCmd) ->
            let
                ( subModel, subCmd ) =
                    DatePicker.init
            in
                ( { outerModel
                | date = maybeDate
                , datePicker = subModel }
                , Cmd.batch [outerCmd, Cmd.map DatePickerMsg subCmd]
                )
-- With usage
init =
    ({}, Cmd.none)
    |> datePicker.init Nothing
        -}
    , view =
        \outerModel ->
            DatePicker.view outerModel.date customSettings outerModel.datePicker
                |> Html.map DatePickerMsg
    , update =
        \msg (outerModel, outerCmd) ->
            let
                ( newDatePicker, datePickerCmd, newDate ) =
                    DatePicker.update settings outerModel.datePicker msg outerModel.date
            in
                ({ outerModel
                    | date = newDate
                    , datePicker = newDatePicker
                 }
                , Cmd.batch [outerCmd, Cmd.map DatePickerMsg datePickerCmd]
                )
    }



init : ( Model, Cmd Msg )
init =
    let
        ( subModel, subCmd ) =
            DatePicker.init
    in
        ( { date = Nothing
          , datePicker = subModel }
        , Cmd.map DatePickerMsg subCmd
        )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DatePickerMsg subMsg ->
            (model, Cmd.none)
            |> datePicker.update subMsg


view : Model -> Html Msg
view model =
    div []
        [ case model.date of
            Nothing ->
                h1 [] [ text "Pick a date" ]

            Just date ->
                h1 [] [ text <| formatDate date ]
        , datePicker.view model
        ]


formatDate : Date -> String
formatDate d =
    toString (month d) ++ " " ++ toString (day d) ++ ", " ++ toString (year d)


main : Program Never Model Msg
main =
    Html.program
        { init = init
        , update = update
        , view = view
        , subscriptions = always Sub.none
        }
