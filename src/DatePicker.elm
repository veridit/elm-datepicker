module DatePicker
    exposing
        ( Msg
        , Settings
        , Model
        , UiState
        , defaultSettings
        , init
        , initFromDate
        , initFromDates
        , update
        , view
        , pick
        , isOpen
        , between
        , moreOrLess
        , off
        , from
        , to
        , focusedDate
        )

{-| A customizable date picker component.


# Tea ☕

@docs Msg, UiState, Model
@docs init, initFromDate, initFromDates, update, view, isOpen, focusedDate


# Settings

@docs Settings, defaultSettings, pick, between, moreOrLess, from, to, off

-}

import Date exposing (Date, Day(..), Month, day, month, year)
import DatePicker.Date exposing (..)
import Html exposing (..)
import Html.Attributes as Attrs exposing (href, placeholder, tabindex, type_, value, selected)
import Html.Events exposing (on, onBlur, onClick, onInput, onFocus, onWithOptions, targetValue)
import Html.Keyed
import Json.Decode as Json
import Task

{-| The single source of truth for the currently selected date. -}
type alias Model = Maybe Date

{-| An opaque type representing messages that are passed inside the UiState.
-}
type Msg
    = CurrentDate Date
    | ChangeFocus Date
    | Pick Model
    | Text String
    | SubmitText
    | Focus
    | Blur
    | MouseDown
    | MouseUp


{-| The type of date picker settings.
The settings contain functions, and is therefore not suitable for storage
in a model, but should rather be just a constant.
-}
type alias Settings =
    { placeholder : String
    , classNamespace : String
    , containerClassList : List ( String, Bool )
    , inputClassList : List ( String, Bool )
    , inputName : Maybe String
    , inputId : Maybe String
    , inputAttributes : List (Html.Attribute Msg)
    , isDisabled : Date -> Bool
    , parser : String -> Result String Date
    , dateFormatter : Date -> String
    , dayFormatter : Day -> String
    , monthFormatter : Month -> String
    , yearFormatter : Int -> String
    , cellFormatter : String -> Html Msg
    , firstDayOfWeek : Day
    , changeYear : YearRange
    }


type alias UiStateData =
    { open : Bool
    , forceOpen : Bool
    , focused :
        Model

    -- date currently center-focused by picker, but not necessarily chosen
    , inputText :
        Maybe String
    , today :
        Date

    -- actual, current day as far as we know
    }


{-| The ui UiState. Opaque, hence no field docs.
-}
type UiState
    = UiState UiStateData


{-| A record of default settings for the date picker. Extend this if
you want to customize your date picker.

    import DatePicker exposing (defaultSettings)

    DatePicker.init { defaultSettings | placeholder = "Pick a date" }

To disable certain dates:

    import Date exposing (Day(..), dayOfWeek)
    import DatePicker exposing (defaultSettings)

    DatePicker.init { defaultSettings | isDisabled = \d -> dayOfWeek d `List.member` [ Sat, Sun ] }

-}
defaultSettings : Settings
defaultSettings =
    { placeholder = "Please pick a date..."
    , classNamespace = "elm-datepicker--"
    , containerClassList = []
    , inputClassList = []
    , inputName = Nothing
    , inputId = Nothing
    , inputAttributes =
        [ Attrs.required False
        ]
    , isDisabled = always False
    , parser = Date.fromString
    , dateFormatter = formatDate
    , dayFormatter = formatDay
    , monthFormatter = formatMonth
    , yearFormatter = toString
    , cellFormatter = formatCell
    , firstDayOfWeek = Sun
    , changeYear = off
    }


yearRangeActive : YearRange -> Bool
yearRangeActive yearRange =
    yearRange /= Off


{-| Select a range of date to display

    DatePicker.init { defaultSettings | changeYear = between 1555 2018 }

-}
between : Int -> Int -> YearRange
between start end =
    if start > end then
        Between end start
    else
        Between start end


{-| Select a symmetric range of date to display

    DatePicker.init { defaultSettings | changeYear = moreOrLess 10 }

-}
moreOrLess : Int -> YearRange
moreOrLess range =
    MoreOrLess range


{-| Select a range from a given year to this year

    DatePicker.init { defaultSettings | changeYear = from 1995 }

-}
from : Int -> YearRange
from year =
    From year


{-| Select a range from this year to a given year

    DatePicker.init { defaultSettings | changeYear = to 2020 }

-}
to : Int -> YearRange
to year =
    To year


{-| Turn off the date range

    DatePicker.init { defaultSettings | changeYear = off }

-}
off : YearRange
off =
    Off


formatCell : String -> Html Msg
formatCell day =
    text day


{-| The default initial state of the Datepicker. You must execute
the returned command (which, for the curious, sets the current date)
for the date picker to behave correctly.

    init =
        let
            ( datePicker, datePickerCmd ) =
                DatePicker.init
        in
            ({ picker = datePicker }, Cmd.map DatePickerMsg datePickerCmd)

-}
init : ( UiState, Cmd Msg )
init =
    ( UiState <|
        { open = False
        , forceOpen = False
        , focused = Just initDate
        , inputText = Nothing
        , today = initDate
        }
    , Task.perform CurrentDate Date.now
    )


{-| Initialize a DatePicker with a given Date

    init date =
        { picker = DatePicker.initFromDate date } ! []

-}
initFromDate : Date -> UiState
initFromDate date =
    UiState <|
        { open = False
        , forceOpen = False
        , focused = Just date
        , inputText = Nothing
        , today = date
        }


{-| Initialize a DatePicker with a date for today and Maybe a date picked

    init today date =
        { picker = DatePicker.initFromDates today date } ! []

-}
initFromDates : Date -> Model -> UiState
initFromDates today date =
    UiState <|
        { open = False
        , forceOpen = False
        , focused = date
        , inputText = Nothing
        , today = today
        }


prepareDates : Date -> Day -> { currentMonth : Date, currentDates : List Date }
prepareDates date firstDayOfWeek =
    let
        start =
            firstOfMonth date |> subDays 6

        end =
            nextMonth date |> addDays 6
    in
        { currentMonth = date
        , currentDates = datesInRange firstDayOfWeek start end
        }


{-| Expose if the datepicker is open
-}
isOpen : UiState -> Bool
isOpen (UiState model) =
    model.open


{-| Expose the currently focused date
-}
focusedDate : UiState -> Model
focusedDate (UiState model) =
    model.focused


{-| The date picker update function. The third tuple member represents a user action to change the
date.
-}
update : Settings -> UiState -> Msg -> Model -> ( UiState, Cmd Msg, Model )
update settings (UiState ({ forceOpen, focused } as model)) msg modelDate =
    case msg of
        CurrentDate date ->
            ( UiState { model | focused = Just date, today = date }, Cmd.none, modelDate )

        ChangeFocus date ->
            ( UiState { model | focused = Just date }, Cmd.none, modelDate )

        Pick date ->
            ( UiState
                { model
                    | open = False
                    , inputText = Nothing
                    , focused = Nothing
                }
            , Cmd.none
            , date
            )

        Text text ->
            ( UiState { model | inputText = Just text }, Cmd.none, modelDate )

        SubmitText ->
            let
                isWhitespace =
                    String.trim >> String.isEmpty

                newDate =
                    let
                        text =
                            model.inputText |> Maybe.withDefault ""
                    in
                        if isWhitespace text then
                            modelDate
                        else
                            case settings.parser text of
                                Ok date ->
                                    if settings.isDisabled date then
                                        Nothing
                                    else
                                        Just date

                                Err _ ->
                                    Nothing
            in
                ( UiState <|
                    { model
                        | inputText =
                            if newDate /= modelDate then
                                Nothing
                            else
                                model.inputText
                        , focused =
                            if newDate /= modelDate then
                                newDate
                            else
                                model.focused
                    }
                , Cmd.none
                , newDate
                )

        Focus ->
            ( UiState { model | open = True, forceOpen = False }, Cmd.none, modelDate )

        Blur ->
            ( UiState { model | open = forceOpen }, Cmd.none, modelDate )

        MouseDown ->
            ( UiState { model | forceOpen = True }, Cmd.none, modelDate )

        MouseUp ->
            ( UiState { model | forceOpen = False }, Cmd.none, modelDate )


{-| Generate a message that will act as if the user has chosen a certain date,
so you can call `update` on the model yourself.
Note that this is different from just changing the "current chosen" date,
since the picker doesn't actually have internal state for that.
Rather, it will:

  - change the calendar focus

  - replace the input text with the new value

  - close the picker

    update datepickerSettings (pick (Just someDate)) datepicker

-}
pick : Model -> Msg
pick =
    Pick


{-| The date picker view. The Date passed is whatever date it should treat as selected.
-}
view : Model -> Settings -> UiState -> Html Msg
view pickedDate settings (UiState ({ open } as model)) =
    let
        class =
            mkClass settings

        potentialInputId =
            settings.inputId
                |> Maybe.map Attrs.id
                |> (List.singleton >> List.filterMap identity)

        inputClasses =
            [ ( settings.classNamespace ++ "input", True ) ]
                ++ settings.inputClassList

        inputCommon xs =
            input
                ([ Attrs.classList inputClasses
                 , Attrs.name (settings.inputName ?> "")
                 , type_ "text"
                 , on "change" (Json.succeed SubmitText)
                 , onInput Text
                 , onBlur Blur
                 , onClick Focus
                 , onFocus Focus
                 ]
                    ++ settings.inputAttributes
                    ++ potentialInputId
                    ++ xs
                )
                []

        dateInput =
            inputCommon
                [ placeholder settings.placeholder
                , model.inputText
                    |> Maybe.withDefault
                        (Maybe.map settings.dateFormatter pickedDate
                            |> Maybe.withDefault ""
                        )
                    |> value
                ]

        containerClassList =
            ( "container", True ) :: settings.containerClassList
    in
        div
            [ Attrs.classList containerClassList ]
            [ dateInput
            , if open then
                datePicker pickedDate settings model
              else
                text ""
            ]


datePicker : Model -> Settings -> UiStateData -> Html Msg
datePicker pickedDate settings ({ focused, today } as model) =
    let
        currentDate =
            focused ??> pickedDate ?> today

        { currentMonth, currentDates } =
            prepareDates currentDate settings.firstDayOfWeek

        class =
            mkClass settings

        classList =
            mkClassList settings

        firstDay =
            settings.firstDayOfWeek

        arrow className message =
            a
                [ class className
                , href "javascript:;"
                , onClick message
                , tabindex -1
                ]
                []

        dow d =
            td [ class "dow" ] [ text <| settings.dayFormatter d ]

        picked d =
            pickedDate
                |> Maybe.map
                    (dateTuple >> (==) (dateTuple d))
                |> Maybe.withDefault False

        day d =
            let
                disabled =
                    settings.isDisabled d

                props =
                    if not disabled then
                        [ onClick (Pick (Just d)) ]
                    else
                        []
            in
                td
                    ([ classList
                        [ ( "day", True )
                        , ( "disabled", disabled )
                        , ( "picked", picked d )
                        , ( "today", dateTuple d == dateTuple currentDate )
                        , ( "other-month", month currentMonth /= month d )
                        ]
                     ]
                        ++ props
                    )
                    [ settings.cellFormatter <| toString <| Date.day d ]

        row days =
            tr [ class "row" ] (List.map day days)

        days =
            List.map row (groupDates currentDates)

        onPicker ev =
            Json.succeed
                >> onWithOptions ev
                    { preventDefault = False
                    , stopPropagation = True
                    }

        onChange handler =
            on "change" <| Json.map handler targetValue

        isCurrentYear selectedYear =
            year currentMonth == selectedYear

        yearOption index selectedYear =
            ( toString index
            , option [ value (toString selectedYear), selected (isCurrentYear selectedYear) ]
                [ text <| toString selectedYear ]
            )

        dropdownYear =
            Html.Keyed.node "select"
                [ onChange (newYear currentDate >> ChangeFocus), class "year-menu" ]
                (List.indexedMap yearOption
                    (yearRange { currentMonth = currentMonth, today = today } settings.changeYear)
                )
    in
        div
            [ class "picker"
            , onPicker "mousedown" MouseDown
            , onPicker "mouseup" MouseUp
            ]
            [ div [ class "picker-header" ]
                [ div [ class "prev-container" ]
                    [ arrow "prev" (ChangeFocus (prevMonth currentDate)) ]
                , div [ class "month-container" ]
                    [ span [ class "month" ]
                        [ text <| settings.monthFormatter <| month currentMonth ]
                    , span [ class "year" ]
                        [ if not (yearRangeActive settings.changeYear) then
                            text <| settings.yearFormatter <| year currentMonth
                          else
                            Html.Keyed.node "span" [] [ ( toString (year currentMonth), dropdownYear ) ]
                        ]
                    ]
                , div [ class "next-container" ]
                    [ arrow "next" (ChangeFocus (nextMonth currentDate)) ]
                ]
            , table [ class "table" ]
                [ thead [ class "weekdays" ]
                    [ tr []
                        [ dow <| firstDay
                        , dow <| addDows 1 firstDay
                        , dow <| addDows 2 firstDay
                        , dow <| addDows 3 firstDay
                        , dow <| addDows 4 firstDay
                        , dow <| addDows 5 firstDay
                        , dow <| addDows 6 firstDay
                        ]
                    ]
                , tbody [ class "days" ] days
                ]
            ]


{-| Turn a list of dates into a list of date rows with 7 columns per
row representing each day of the week.
-}
groupDates : List Date -> List (List Date)
groupDates dates =
    let
        go i xs racc acc =
            case xs of
                [] ->
                    List.reverse acc

                x :: xs ->
                    if i == 6 then
                        go 0 xs [] (List.reverse (x :: racc) :: acc)
                    else
                        go (i + 1) xs (x :: racc) acc
    in
        go 0 dates [] []


mkClass : Settings -> String -> Html.Attribute msg
mkClass { classNamespace } c =
    Attrs.class (classNamespace ++ c)


mkClassList : Settings -> List ( String, Bool ) -> Html.Attribute msg
mkClassList { classNamespace } cs =
    List.map (\( c, b ) -> ( classNamespace ++ c, b )) cs
        |> Attrs.classList


(?>) : Maybe a -> a -> a
(?>) =
    flip Maybe.withDefault


(??>) : Maybe a -> Maybe a -> Maybe a
(??>) first default =
    case first of
        Just val ->
            Just val

        Nothing ->
            default
