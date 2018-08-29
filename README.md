# elm-elements-datepicker

A reusable date picker component in Elm with Style Elements.

## Installation

``` shell
elm package install veridit/elm-elements-datepicker
```

## Usage

1. Add a date and the date picker state to your `Model`.
2. Add a `Msg` for forwarding messages to the datepicker.
3. Edit `init`, `update` and `view` to use the datepicker.
4. Optionally adjust the settings of the date picker.


### Walkthrough

Add a date and the date picker state to your `Model`.
```elm
   
type alias Model =
  { ...
  , date : DatePicker.Model
  , datePicker : DatePicker.UiState
  ...
  }

```

Add a `Msg` for forwarding messages to the datepicker.

```elm
   
type Msg
  = ...
  | DatePickerMsg DatePicker.Msg
  ...
```


Edit `init`, `view` and `update` to use the datepicker.

`init`

```elm
   
init : (Model, Cmd Msg)
init = 
    let
        ( datePicker, datePickerCmd ) =
            DatePicker.init 
    in
        ( { date = ... , datePicker = datePicker }
        , Cmd.map DatePickerMsg datePickerCmd
        )
```

Prepare default settings

```elm
datePickerSettings = DatePicker.defaultSettings
```

`view`

```elm
view : Model -> Element Msg
view model =
    ...
    column []
        [ DatePicker.view
            datePickerSettings
            model.datePicker
            model.date
         |> Html.map DatePickerMsg
        ]
```

`update`

```elm
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ...

         DatePickerMsg msg ->
            let
                ( newDatePicker, datePickerCmd, newDate ) =
                    DatePicker.update datePickerSettings model.startDatePicker msg model.date
            in
                ({ model
                    | date = newDate
                    , datePicker = newDatePicker
                 }
                , Cmd.map SetDatePicker datePickerCmd
                )

```

Adjust the settings of the datepicker (Optional)

```elm
someSettings : DatePicker.Settings
someSettings = 
    { defaultSettings
        | inputClassList = [ ( "form-control", True ) ]
        , inputId = Just "datepicker"
    }
```


## Examples

See the [examples][examples] folder or try it on ellie-app: [simple] example and [bootstrap] example.

[examples]: https://github.com/elm-community/elm-datepicker/tree/master/examples
[simple]: https://ellie-app.com/5QFsDgQVva1/0
[bootstrap]: https://ellie-app.com/pwGJj5T6TBa1/0


## Styling

The CSS for the date picker is distributed separately.  You can grab
the compiled CSS from [here][compiled] or you can grab the SCSS source
from [here][scss].

[compiled]: https://github.com/elm-community/elm-datepicker/blob/master/css/elm-datepicker.css
[scss]: https://github.com/elm-community/elm-datepicker/blob/master/css/elm-datepicker.scss


## Architecture

Goals

1. Elm debug compatible.
2. Single source of truth.
3. Simple API for simple usage, advanced API for advanced usage.
4. Embeddable in non elm projects.

Considerations to reach those goals

### Elm debug compatible.

The data model inside the date picker can not contain any functions, but functions are used to configure the
behaviour of the date picker. Therefore state is stored in the model, and a separate record of configuration
is given to the update and view functions, but is not stored in neither the model of the date picker,
nor in the model where the date picker is used.

### Single source of truth.
By avoiding the storage of a date in the date picker model, the code that embeds the date picker always
has access to and control over the date. This is as outlined [here](https://github.com/evancz/elm-sortable-table#single-source-of-truth)


### Simple API for simple usage, advanced API for advanced usage.

1. Simple API has no configuration or adjustments.
2. Advanced API for configuration.

### Embeddable in non elm projects.
Allow other projects the the speed and stability of Elm by offering an embeddable date picker.

## Running the acceptance tests
### Prerequisites

- elm reactor - this is most likely already installed if you're using Elm!
- chromedriver (https://sites.google.com/a/chromium.org/chromedriver/).
  Try `brew install chromedriver` if you're on OSX.


### Install the testing tools
run `npm install`

### build the examples
cd examples && make && cd ..

### Run the tests
`./run-acceptance-tests`

Please file an issue if you have any difficulty running the tests.

