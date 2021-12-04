+++
title = "Elm Frontend in Hugo Static Site"
description = "Elm Frontend component embedded in Hugo Static Site"
tags = [
    "hugo",
    "elm",
]
date = "2021-11-27"
categories = [
    "hugo",
    "elm",
]
+++

To view the Elm component in action - scroll down to the [Elm Component Demonstration](/elm-in-hugo#elm-component-demonstration) section

## Motivation

I wanted to learn to try to write a Frontend Application that provide some sort of dynamic functionality - e.g. doing quick mathematical calculation, fetching data from some backend APIs etc. However, the frontend world is a pretty complex world (and continues to be so to date) - there are many factors to take note when writing it:

- Choice of frontend language/framework
- Single Page Application? Or embed javascript to server rendered page?
- SEO considerations?

## Choice of frontend language

Regarding frontend language - we are usually restricted to using Javascript and the various frameworks built for it. The popular ones as at the time of writing is React, Vue and Angular. Fortunately and unfortunately, I did try coding using React and Vue; and they turn out to be way more complex than what I would like. Complexity is a big problem for me since I would mostly be coding backend/automation devops pipelines. I would only touch frontend code very rarely - so I need code which is kind of easy to read, have strong hints and easy to come back to. Both react and vue is hard the moment one requires to interact with some backend system - suddenly complex libraries that deal with state management app-wide (referring to redux and vuex here) suddenly come up - and those libraries are tremendously complex. 

Also, an additional painpoint, there is also the webpack system that is kind of "needed" to ensure javascript is transpiled safely to a "compatible" version that works from the browsers that the application developer wishes to update. Although we can just rely on initial code generation tools (e.g. Create React App cli tooling) to generate initial version of webpack we may use, there is still an irksome feeling of using something that would require some configuration but its just something we just implicitly trust and leave alone because "it just works" at the moment.

Most likely all the above "mini rants" is more of a personal taste - it could be mostly from a bad experience of working with some messy react and vue code - there could be a possibility that react and elm code is extremely elegant and very easy to understand.

For now, I currently write the frontend code in a programming language called [Elm](https://elm-lang.org/). It has pretty much a lot of nice properties but the main pulling factor is the debug messages that literally "scream" where the issue with the code is. Other nice properties include:

- Very descriptive error messages
- Static typing (At this point, I really hate coding in dynamic typing programming languages - with Static typing, you can actually avoid a whole class of coding issues and also, have decent type hinting in your respective IDE)
- Cannot "compile" code if there are bad logic implementations - e.g. the language attempts to force you to implement every branch/if condition where possible to ensure there is no "unexpected" view on frontend
- Simple toolchain; just elm cli. No webpack, gulp, grunt to configure
- Language kind of requires for functions that one writes to be "pure" - function that have 0 side effects - which makes code very testable and makes it easy to transpiler to optimize the code (removing unnecessary code is easy in the case of pure functions as compared code written with object oriented style). We can wonder why this is the case; you can just refer to the following repo: https://github.com/you-dont-need/You-Dont-Need-Momentjs

You can probably read more of the benefits on the Elm Homepage

There are of course certain disadvantages:

- Elm is less popular to React, Vue, Angular - so this would mean that there would be less guidance available on the internet to follow. Most likely you would need to rely on the reference library documentation in order to code things out rather than "copy and paste" from the various Stack Overflow posts or Medium Articles or Github Gists etc
- Elm is harder to get used to - its more of a functional programming style? I'm mostly used to object oriented programming where we create "object" structures in codebases and add properties and functions to said objects. However, everything in elm is a function, and all these functions are used to pipe their outputs into each other.

## SPA vs SSR

This is the one that befuddled me the most - deciding how the application is going to the internet.

The initial thought would be to code a "normal" Elm application. The Elm application would have capability the handle routing and other logic. All frontend based logic would be handled within the app itself (and this is the start of the problem)

The main concern mostly stem from following some of the usual SEO praticses out there:

- If possible, ensure Server side render - so that bot from Google can actually pick up the page correctly when it is attempting to index. There could be a possibility that SPA takes a while to render and the indexing process might have accidentally take a "premature" version of the render of the page. (Haven't seen much of SSR Elm - maybe only the Elm-Pages github project)
- Ensure there is a Sitemaps site (Elm cannot present a simple XML page - how I created it was generate a JS and embed it into a HTML page; even if I can generate the XML, it would be embedded into a HTML, this is the format that Google Search Indexing is looking for)
- Need to add meta tags in head tags of HTML - provide meta description and meta tags to handle how the page would look like on facebook/linkedin etc (This is impossible to do in Elm)

The 3 reasons above made me question whether to deploy a separate Elm website on a different domain - it would just mean that the page would be totally "invisible" on the world wide web. Search indexing is still necessary for pages to appear in Google search results. The page becomes less useful if it is not discoverable via Google searches.

With that, I'm currently experimenting with adding such functionality coded in Elm into this blog (which is generated via Hugo). There are some weird hacks needed since the application kind of goes through netlify build processes - hopefully, it won't be too much issue with continuing the hacks.

## Elm Component Demonstration

The demonstrated elm component is below the horizontal line. It only has a simple functionality as the main aim is just to demonstrate that it is possible to embed such code into hugo in the first place. (Although it's done in a pretty hacky way)

The application stores a counter and displays it to you, the user. If you click on the "+" button, the value of the counter rise by 1 and if you click on the "-" button, the value of the counter drops by 1.

---

{{< sample >}}

## Elm codebase

You can view the code for the above tool in the following Github repo:  
https://github.com/hairizuanbinnoorazman/blog/blob/master/tools/src/Sample.elm

The most important bit would be the "view"

```elm
view : Model -> Html Msg
view model =
    div []
        [ p [] [ text ("Value: " ++ String.fromInt model.value) ]
        , button [ style "height" "50px", style "width" "100px", onClick Increment ] [ text "+" ]
        , button [ style "height" "50px", style "width" "100px", onClick Decrement ] [ text "-" ]
        ]
```

It is a pretty simple view which prints: "Value: XX" where XX is the counter number that the application is handling. It would also have 2 buttons - 1 to increment by 1 and the other is to decrement by 1. The buttons are handled are by `onClick` events.

The `onClick` events are handled here:

```elm
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Increment ->
            ( { model | value = model.value + 1 }, Cmd.none )

        Decrement ->
            ( { model | value = model.value - 1 }, Cmd.none )
```

Essentially, the events would alter the centralized store of value; which is this case is the "mode" object which has the value field.

Of course, when application starts, we need to initialize the application by setting an initial value. The initialization of the app is handled by the `init` function

```elm
init : ( Model, Cmd Msg )
init =
    ( Model 0, Cmd.none )
```

We can view this by running `elm reactor` and viewing it on the browser during development phase.

The app here can be "compiled" into a javascript script which we can then embed it into html. In our case, we are trying to embed it into hugo. To make it easy to embed this into various posts in this blog, we can do so by creating custom shortcodes. You can refer making of shortcodes in hugo here: https://gohugo.io/templates/shortcode-templates/

The commands to do this:

```bash
elm make --optimize --output=sample.js ./src/Sample.elm
uglifyjs sample.js --compress "pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe" | uglifyjs --mangle --output sample.min.js
```

The first command would generate the js that we can be used to embed into html. THe second bash command is more of an optimization step. As we know, javascript is a script - it's not compiled to binary. We would be shipping the whole script over to the client side. It's actually best to ensure that the javascript script is as small as possible and this is done by uglifyjs - it would reduce all the empty spaces as well replace long descriptive functions name to alphabets (essentially making it really really hard to read the code in that format - but extermely light to send it off to client). This process can sometimes can the amount of space used by the script by almost 80% which is a huge amount saving on network bandwidth of sending the js scripts over the wire.

To create the shortcode in Hugo using the generated javascript of the elm component:  

```html
<div id="sample-elm"></div>
<script src="{{ "toolsjs/sample.min.js" | relURL}}"></script>
<script>
    app = Elm.Sample.init({ node: document.getElementById("sample-elm") });
</script>
```

First step is actually to have the `div` with the id. I'm not exactly sure if there are other html elements that are used by this hugo template - hence, I added `-elm` in the id to ensure that there is no duplicate element with the same id. We would then load up the javascript script. The loaded javascript script will provide elements for us to initialize and start the app.

## Concluding words

I actually didn't expect this mish mash of technologies to work in the first place. However, it does seem nice that Elm have provided the mechanism (which is probably gonna be permanent) because applications that would want to try Elm but yet wouldn't want to invest 100% into it can try by having Elm take over certain elements in the html page.

So far, I don't actually forsee too many issues with this approach - but maybe, with more elm components, there could be potential issues - we shall see.