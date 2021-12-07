+++
title = "Build Chat App with Golang Websocket and Elm Frontend"
description = "Build Chat App with Golang Websocket and Elm Frontend in Hugo Static Sites"
tags = [
    "hugo",
    "elm",
    "golang",
]
date = "2021-12-20"
categories = [
    "hugo",
    "elm",
    "golang",
]
+++

While building Elm based frontends, I decided to take the opportunity to learn on how to craft a chat application. Truthfully, I've never really built one before (nor do I need to). But it does seem like an interesting programming exercise to kind of go thru - in order to understand how such applications are built, deployed, scaled and managed. For the frontend, I'm mostly set to use Elm (probably you've seen a [previous post](/elm-frontend-in-hugo-static-site) on my "dislike" for other Javascript based frameworks, which is essentially all the popular ones in the market). For backend, I will probably stick to Golang since that is the language I'm most comfortable with (all hail statically typed languages)

The backend code base for the chat application can be found here:  
https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/basicWebsocket

The backend code is modified from the example:  
https://github.com/gorilla/websocket/tree/master/examples/chat

For the codebase, we're heavily using various components from the gorilla golang libraries - including the `gorilla/mux` library and the `gorilla/securecookie` library. You'll probably understand why those libraries are used as you continue reading on this blog post.

The main aim of this sample chat application is to be able to create some sort of Elm component that can be embedded into a html page. Unfortunately, I will not be making a this Elm component to be embedded in this blog post as the it feels like there isn't enough features to showcase it (although, there are plenty of interesting items that one can come around during development work). Most likely, in the futre, there will be another blog post that will include the demonstration as well as other interesting features I intend to add to such sample application (e.g. making chat messages persistent, allow creating of multiple chat rooms etc).

The rest of the sections of the blog post will not be covering on each detail in the codebase but instead will be covering on the more interesting aspects of the codebase. Most of this sections are the parts where I kind of tripped over while building the Golang application backend.

## Adding CORS

The first step is to make it possible for our Elm component to talk to our backend. This is done via CORS (Cross Origin Resource Sharing). This happens due to the domain of frontend is different as compared to the backend - hence, by default, it shouldn't be trusted. A reminder here that the frontend is build with Elm and is injected to a html page as a Single Page Application (SPA)

In Golang, we can easily resolve this by importing some sort of CORS library. Refer to the codebase highlighted below - you can find this in the `main.go` file of the folder of the repo.

```go
import "github.com/rs/cors"

...

c := cors.New(cors.Options{
		AllowedOrigins: []string{"*"},
		AllowedMethods: []string{"*"},
	})

...
```

Do note that the configuration here is "very bad" - essentially, an "allow all" kind of configuration. For testing purposes, it may be ok but we definitely need to clamp down on what origins can contact the server and what methods it can use to access as well. We would definitely need to ensure that only the right frontend can access the backend.

## Checking frontend while creating websocket connection

There is no "protection" mechanism to prevent the browser from making unauthorized access to any server. Any of such protection mechanism has to be implemented on the backend - which is our Golang server.

By default, the library being used here "gorilla/websocket", will at least minimally ensure that the frontend calling the backend is at least of the same domain. In order to accomodate the usage of Elm, we would need to add the following modification:

```go
var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		_, err := r.Cookie("cookie-name")
		if err != nil {
			return false
		}
		return true
	},
}
```

The important function (without which, we can't use Elm to run our "chat" application) is the `CheckOrigin` function. If it is not modified, we would be seeing the following issue: 

```bash
upgrade:websocket: request origin not allowed by Upgrader.CheckOrigin
```

There are a few approaches that we can use to check whether to allow the establishment of the websocket connection - one way is to check for the domain where this is request from etc. Another way that I thought that could be done is to pass sort of http header as we're trying to establish the websocket connection - but it does seem like that approach may not be possible. 

The easier way to pass all the extra data that is required to establish and initalize the websocket connection is via cookies (which it seems to be passed the moment the websocket is attempted to be established).

This was why we have a route to create the cookie (which we will describe in the next section)

Refer to the following issue for more details of how to resolve the issue:  
https://github.com/gorilla/websocket/issues/367

## Adding route to create cookie

```go
var hashKey = []byte("very-secret")
var blockKey = []byte("a-lot-secret")
var s = securecookie.New(hashKey, blockKey)

type HomeHandler struct{}

func (h HomeHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	value := map[string]string{
		"foo": "bar",
	}
	if encoded, err := s.Encode("cookie-name", value); err == nil {
		cookie := &http.Cookie{
			Name:     "cookie-name",
			Value:    encoded,
			Path:     "/",
			Secure:   true,
			HttpOnly: true,
		}
		log.Printf("Cookie Generated :: %v", encoded)
		http.SetCookie(w, cookie)
	}
	log.Println("Home Handler endpoint reached")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("OK"))
}
```

This section of code seem to showcase how we can attempt to create the cookie (which we kind of need to establish some sort of protection for our server when attempting to establish the websocket connection to our server.)

## Elm code

I'm going to further develop it; so this will be snapshot of what that would work with the Golang server at this point of time.

```elm
port module Chat exposing (..)

import Browser
import Html exposing (Html, button, div, input, li, text, ul)
import Html.Attributes exposing (placeholder, type_, value)
import Html.Events exposing (on, onClick, onInput)
import Json.Decode as D


main : Program () Model Msg
main =
    Browser.element
        { view = view
        , init = \() -> init
        , update = update
        , subscriptions = subscriptions
        }


subscriptions : Model -> Sub Msg
subscriptions _ =
    messageReceiver Recv


port sendMessage : String -> Cmd msg


port messageReceiver : (String -> msg) -> Sub msg


type alias Model =
    { draft : String
    , messages : List String
    }


init : ( Model, Cmd Msg )
init =
    ( Model "" [], Cmd.none )


type Msg
    = DraftChanged String
    | Send
    | Recv String


view : Model -> Html Msg
view model =
    div []
        [ ul []
            (List.map (\msg -> li [] [ text msg ]) model.messages)
        , input
            [ type_ "text"
            , placeholder "Draft"
            , onInput DraftChanged
            , on "keydown" (ifIsEnter Send)
            , value model.draft
            ]
            []
        , button [ onClick Send ] [ text "Send" ]
        ]


ifIsEnter : msg -> D.Decoder msg
ifIsEnter msg =
    D.field "key" D.string
        |> D.andThen
            (\key ->
                if key == "Enter" then
                    D.succeed msg

                else
                    D.fail "some other key"
            )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DraftChanged draft ->
            ( { model | draft = draft }
            , Cmd.none
            )

        Send ->
            ( { model | draft = "" }
            , sendMessage model.draft
            )

        Recv message ->
            ( { model | messages = model.messages ++ [ message ] }
            , Cmd.none
            )

```

The important bit is embedding it into HTML. There is no proper support for websockets in Elm but we can have the Elm application interface with javascript via Ports. Refer to this on Elm documentation: https://guide.elm-lang.org/interop/ports.html

The Elm code here is almost the same as the one provided by the guide.

For the html piece - O will be providing what would be created if one would to add it to a hugo shortcode:

```html
<div id="chat"></div>
<script src="{{ "toolsjs/chat.min.js" | relURL}}"></script>
<script>
    app = Elm.Chat.init({ node: document.getElementById("chat") });
    var socket = new WebSocket('ws://localhost:8080/ws');
    app.ports.sendMessage.subscribe(function(message) {
        socket.send(message);
    });
    socket.addEventListener("message", function(event) {
        app.ports.messageReceiver.send(event.data);
    });
</script>
```

We would load our generated javascript of our Elm codebase and have that load up our generated javascript and start an app. We would then create a websocket which would then interact with the app - as messages go in and out of the app - the string will be fed into application which would then be rendered onto the screen.

The following Elm application is pretty simple and doesn't take into question such as - in the case, we need to authenticate the user before establishing the websocket connection; how do we dynamically create the websocket only when we've checked within elm that the user has already "logged" in.
