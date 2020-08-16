+++
title = "Implications for having switchable loggers"
description = "Utilizing interfaces in golang to allow switchable loggers in golang codebases"
tags = [
    "golang",
]
date = "2020-08-16"
categories = [
    "golang",
]
+++

Loggers in codebases are generally code that is just taken for granted. We would usually imagine that we'll just choose a logger library, import it and then just utilize in code. We would probably have the application pass some configuration to the application, maybe to reduce amount of logs printed in production to reduce the amount of load that it would produce in logging aggegration systems.

Usually, this approach wouldn't be a problem. However, what would happen if somehow or other, the logger library that we happened to pick for just happens to be incompatible with our logging aggegation systems? (Yes, fluentbit, beats etc can be configured to all kind of logging formats but it wouldn't make sense to do it on a per component basis - might sense for the platform teams to dictate general logging formats that applications team need to conform to). With incompatible loggers, that would be forced to attempt to switch to logging systems that support it. Changing loggers in application code bases are generally the most painful thing to do - IMO, its almost akin to intellectual torture; a painful exercise.

Another reason to think of having some sort of logger interface is when you're sharing your project's packages with other projects. Let's put an example where your code kind of utilizes a hard coded logger implementation within your project. And let's say by default, the logger will print all statements, including info and debug statements. Without the interface (alternative can consider of accepting a logger function - but that would only allow you to pass 1 logger function), that would mean that the person calling your package have no control over what is being logged out. Just imagine where the compiled components would log out nicely formatted json logs and suddenly it switches to maybe multi-line logs (which your project's package have decided to use). It's a very jarring experience, making it hard to use said package properly.

However, Golang does come with the interface construct. That would allow us to plugin differnt logging systems if we coded it out that way.

## Logger Interface

Let's say we have a http handler.

```golang
type GetPage struct {
    logger logger.Logger
    pageDB page.Store
}

func (p GetPage) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    p.logger.Info("Start of GetPage handler")
    defer p.logger.Info("End of GetPage handler")
    fmt.Fprintf(w, "Hello World: %s!\n", target)
}
```

Notice the `logger.Logger` that is declared as part of the `GetPage` struct. If the logger is a interface, it would then allow us to switch in different logger implementation depending on our use cases.

```golang
// Part of logger package within project
type Logger interface {
	Debug(args ...interface{})
	Debugf(format string, args ...interface{})
	Info(args ...interface{})
	Infof(format string, args ...interface{})
	Warning(args ...interface{})
	Warningf(format string, args ...interface{})
	Error(args ...interface{})
	Errorf(format string, args ...interface{})
}
```

The above is an example of a logger interface. With that, as long as the logger interface

## Extending to using test loggers

In the Visual Studio Code environment, you can run Golang unit tests quite easily. However, sometimes, code in some of these function get particularly complex - there may be too many state transitions in one variables after a whole bunch of functions is used to manipulate it. One way to kind of debug this is to maybe just comment out large sections of code just to be able to view what the current state of some variable which can be logged out in tests.

Just for context, using your default logger and just logging it out don't exactly seem to work as expected - the logs don't exactly get printed out.

Let's say we have the following implementation:

```golang
type LoggerForTests struct {
	Tester *testing.T
}

func (l LoggerForTests) Debug(args ...interface{}) {
	l.Tester.Log(args...)
}

func (l LoggerForTests) Debugf(format string, args ...interface{}) {
	l.Tester.Logf(format, args...)
}

func (l LoggerForTests) Info(args ...interface{}) {
	l.Tester.Log(args...)
}

func (l LoggerForTests) Infof(format string, args ...interface{}) {
	l.Tester.Logf(format, args...)
}

func (l LoggerForTests) Warning(args ...interface{}) {
	l.Tester.Log(args...)
}

func (l LoggerForTests) Warningf(format string, args ...interface{}) {
	l.Tester.Logf(format, args...)
}

func (l LoggerForTests) Error(args ...interface{}) {
	l.Tester.Log(args...)
}

func (l LoggerForTests) Errorf(format string, args ...interface{}) {
	l.Tester.Logf(format, args...)
}
```

This is where having the logger interface that your struct/function accepts and use would allow the capability for people to use the following implementation that is mainly targeted for printing logs out during testing.

## Just additional thoughts

After reading and playing around with several golang codebases, I currently have the following opinion - if a technical decision is needed to be made, then, it's best to utilize it as an interface so that alternative solutions can be used in the future.

Some examples I can easily think of at the moment are datastores, loggers. Maybe in the future, if I discover more cases, then I'll add to the list here.

But as with all things, take all advice with a grain of salt. Introducing interfaces this early into your codebase naturally increases the complexity of your code bases quite a bit. Sometimes, rather than having the interface, maybe the company decided that the place where implementations can be changed is on the network level (calling different endpoints etc) - which would mean that having all this complexity in the code bases would just make it plain old code bloat.
