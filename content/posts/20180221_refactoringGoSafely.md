+++
title = "Refactoring Go Safely"
description = "Ways to handle old code safely without breaking functionality along the way"
tags = [
    "golang",
]
date = "2018-02-21"
categories = [
    "golang",
]
+++

An excellent resource to read on Refactoring Golang code safely and to ensure that Golang code continue does not result in breaking changes in the codebase.  
https://talks.golang.org/2016/refactor.article

An important to take away from the article is the fact that when making API changes to a code base, the portion that results in largest amount of work is the amount of code repair that needs to be done. Here are some of the examples to take note:

This types of code repair refactors would likely happen in the Golang standard libraries.

1.  Moving constants across packages - part of code repair
    ```golang
    const OldAPIConstant = NewPackage.APIConstant
    ```
2.  Moving functions across packages - part of code repair
    ```golang
    // Use OldAPI's signature
    func OldAPI(){
        NewAPI()
    }
    ```
3.  Moving vars across packages - part of code repair
    ```golang
    var OldAPIVariable = NewPackage.APIVariable
    ```
4.  Moving types across packages - part of code repair
    ```golang
    type OldAPIType = Packagetype.NewAPIType
    ```

Here are some additional refactoring notes:

Doing the following adds plenty of extra code to your codebase. If you are sure no one is using the code base - e.g. It's a private repository and nobody else is actually using the same codebase, then, it might be fine to just add/remove or doing other code edits which might usually cause application breakages.

For some that would require breaking changes etc, one extra step that you can do is to actually add a note about depreciation of some functionality and add some information on why the function or variable is depreciated

5.  Add a new field to a struct safely (Don't depreciate it yet - adding of new fields might result in unexpected behaviours?)

```golang
type Planet struct {
    Name   string  `json:"name"`
    Radius float64 `json:"radius"`
}

type PlanetWithMass struct {
    Planet
    Mass float64 `json:"mass"`
}
```

6.  Add a new parameter to a function - note (This is for temporary, once it is ok to do a major release, can clean out past versions)

```golang
// Test1 is the old function - move code to new function
// Test1WithOwner is the new function

func Test1(name string){
    // fmt.Println(name) - past code - move it to new function or a common function that has been extracted sufficiently.
    Test2(name, "")
}

func Test1WithOwner(name, owner string){
    fmt.Println(name)
    if owner != "" {
        fmt.Println(owner)
    }
}
```
