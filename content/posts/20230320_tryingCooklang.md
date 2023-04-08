+++
title = "Trying cooklang with Golang to document recipes"
description = "Trying cooklang with Golang to document recipes"
tags = [
    "golang",
]
date = "2023-03-20"
categories = [
    "golang",
]
+++

For many people, cooking is not just a means of sustenance but a beloved hobby and a way to express creativity in the kitchen. However, one of the biggest challenges for home cooks is keeping track of their recipes and possibly the list of interesting recipes from other people. In my opinion, it's general a good idea to have a copy of such information on hand (since websites/videos hosting such recipes can eventually disappear). However, recording such information in plain text might be a tad "boring" - it's also harder to kind of parse as well as process further. In this blog post, we will explore using cooklang as a possible tool to "standardize" such information.

Cooklang is a pretty interesting project where it attempts to collect information about recipes and provide a way for computers/scripts to understand and process the information further. When it comes to recipes, there are several important pieces of information that one would need to take note to ensure that one would be able to reproduce piece of food.

- Ingredients and their respective amounts
- Amount of servings that recipe would be producing
- Steps for the cook to follow in order to reproduce the meal
- Equipment that might be needed to produce the meal
- Timings for how long a step would need to be taken (e.g. boil a piece of potato for 10 minutes etc)

It might be convenient to simply just put the information for a recipe to plain old text and have that available on the internet - however, that would make it to utilize and create some sort of web service that would be able to parse and process the information to make it more useful. One possible useful feature that would be nice to have after viewing a recipe would be automatically adding the list of ingredients that we would need to produce the food to be added to some sort of shopping list. In plain text, it might prove a little too troublesome but lucky for us, cooklang has some sort of standardization in place to allow parsing of recipes to be possible that would then allow us to extract even more information to make it useful.

An example recipe written with cooklang would look like the following:

```text
>> tags: american,breakfast
>> servings: 1

Place @bacon{2%slices} in a #large skillet{}. Cook over medium heat until browned. Drain, crumble, and set aside.

In a #stock pot{}, melt @margarine{1/9%cup} over medium heat. Whisk in @flour{1/9%cup} until smooth. Gradually stir in @milk{7/6%cup}, whisking constant until thickened. Stir in @large baked potatoes{2/3} and @green onions{2/3}. Bring to a boil, stirring frequently.

Reduce heat to low, and simmer for ~{10%minutes}. Mix in bacon, @shredded cheddar cheese{1/5%cup}, and @sour cream{1/6%cup}. Then add @salt, and @pepper to taste. Continue cooking, stirring frequently until cheese is melted.

```

Notice the various symbols that is dotted across the entire recipe:

- "@" symbol would indicate an ingredient
- "#" symbol would indicate an equipment for the recipe
- The curly braces "{}" after an ingredient/equipment is used to denote how many of the ingredient/equipment is neeeded.
- ">>" symbol serves to denote metadat to be associated with the recipe. We can use to set "tags" for which we can associate the cuisine of the food which we can then used to do filtering of recipes etc

For full specification of recipes written with cooklang, refer to the following page for it:  
https://cooklang.org/docs/spec/

Technically, we can use the cli tool that is provided to parse our recipe but fortunately, someone took the effort to create a Golang parse that is able to parse recipes written with cooklang. Github repo: https://github.com/justintout/cooklang-go. We can simply utilize this library and then create our code that would be able to understand our recipe.

Let's say we would want to create a piece of code that would be able to get the ingredients that a recipe needs. We can possibly use the output of that code to pass it to some sort of application that would serve as a shopping list.

Another piece of information that might be good to tease out would be "tag" information which might allow us to use it as a way to filter recipes. Imagine a scenario where we somehow store information on 1000s of recipes - it might be hard to remember recipes by name. Hence, we can use tags to find our recipe more easily.

This blog post will only focus on extracting such information from a recipe only though. The ideas mentioned in the above 2 paragraphs might be covered in another post probably. 

Here is the golang code to extract the ingredients as well as to parse tags as comma separated strings

```golang
package main

import (
	"fmt"
	"strings"

	cooklang "github.com/justintout/cooklang-go"
)

func main() {
	fmt.Println("Begin golang code")

	zzz := cooklang.MustParseFile("zzz.cook")
	// fmt.Printf("Test %+v\n", zzz)
	// fmt.Printf("%+v", zzz.Ingredients)
	for i, _ := range zzz.Ingredients {
		fmt.Println(i)
	}

	for j, k := range zzz.Metadata {
		if j == "tags" {
			zz := fmt.Sprintf("%v", j)
			for _, a := range strings.Split(k, ",") {
				zz = fmt.Sprintf("%v == %v", zz, a)
			}
			fmt.Println(zz)
		}
	}
}

```

I will continue experimenting with this and will probably use this for my own use - there are probably a few things that need to taken note of while using cooklang but that will probably be covered in the next blog post.
