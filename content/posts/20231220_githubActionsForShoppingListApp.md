+++
title = "Github actions for shopping list application"
description = "Github actions for shopping list application deployed on Google Cloud Run. Image stored in Artifact registry"
tags = [
    "serverless",
    "docker",
    "google-cloud",
    "cicd",
]
date = "2023-12-20"
categories = [
    "serverless",
    "docker",
    "google-cloud",
    "cicd",
]
+++

I have a basic shopping list application that is available in the following code base: https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Apps/shopping-list. This is a simple Golang application that also embeds a generated javascripts that has been transpiled into Javascript files. We can then embed the required CSS, Javascript and HTML files that would be the frontend of the shopping list. The frontend would then call some backend apis that would simply store shopping list items into some form of datastore - which in this case, is Google Cloud Datastore (a NoSQL database)

TLDR version:

- Frontend
  - ELM -> transpiled to Javascript
  - CSS
  - HTML
- Backend
  - Golang
  - Frontend is embed into Golang
  - Application is baked into a Docker image
  - Database is Google Cloud Datastore
- Deployment
  - Deployed on Google Cloud Run in Singapore region (GCP)
  - CICD pipelines are setup in Github actions

## Manual deployment

Before any CICD pipeline was created, the application was previously deployed manually from a developer's workstation. The commands can be sometimes be rather long and complicated; and hence, makefiles was created which can then be used to simplify the commands that is being used to deploy the application.

In order to get the application to "production", we would need to run various steps that would prepare various files that would need to be included into our docker image. Do take note that our frontend for the shopping list is written using Elm. We do not use Elm directly; we would actually need to take the Elm code base and use it to generate the javascript (that browsers understand) from it. The clean javascript code generated via the Elm code base would then need to be "uglified" and "minified" so as to reduce the chances of attackers attempting to attack the backend by understanding the frontend codebase.

This step is all encapsulated in one make command called:

```bash
make gen-prod
```

This command generates our uglified, minified javascript and move it to a static folder. This step is vital as we would then have our production docker image load it in and use it as part of the static binary build. The make command to build out the production docker image would be:

```bash
make docker-prod
```

This make command would create our needed docker image and push it into a container registry (which is deprecated - remember this for later)

There is no actual cli command to create/update the Cloud Run service. This was done manually via UI (usually used for demo purposes)

## Using CICD Github actions

This worked normally since there is only 1 developer working on it after all (me) but naturally, it would be great to have some sort of CICD pipeline created for it. However, I really would like to replicate the same experience of myself writing this blog as to us, getting the shopping-list application straight to production. I would want processes where upon any code changes - the relevant artifacts would be built and pushed to its respective registries and the Cloud Run service would be updated to the latest image being built.

TLDR for the github actions workflow file is here: https://github.com/hairizuanbinnoorazman/Go_Programming/blob/master/.github/workflows/shopping.yml

Seeing that the whole of `Golang Programming` github repository is on Github - we might as well simply rely on Github actions to do so. (which sounds pretty possible). There are a few things that we would need to tackle to get the whole CI CD pipeline working.

- Test the code (maybe next time?)
- Build the docker image from the code
- Push the docker image into a Private registry
- Update our Cloud Run instance to use the new docker image

For now, we would skip the first portion - might be good to consider adding it next time to make the entire process "safer". The first step would involve running the server in a temporary manner and then hammering it with curl requests. This is mostly to check that the application would be able to store as well as return data records.

The next step is to build the docker image as well as to push the image to a registry. My initial approach to this is to simply follow the manual approach of pushing the docker image into the registry. However, this would require our github actions builder to have the same permissions as my workstation to push the docker image. We would then run the step to modify the docker cli to add mentioned credentials so that our docker cli would be able to push the image to the private Container registry on Google Cloud.

There are 2 problems here. The first is that we would need to figure out how to pass credentials to our github actions builder. In our workstation, we can simply run `gcloud auth login` and it would then prompt us in an interactive fashion to authenticate our gcloud command. We definitely cannot do this on github actions since it's mostly a non-interactive environment (also, imaginge how irritating it would be to almost be prompted by some machine to accept that you're trying to authenticate the gcloud command from some machine that you control)

One solution to solve this is to create a json credentials file from a newly created service account that has all the permissions we need. The json credentials file can be stored on github actions secrets variable and can then be loaded into our github actions job. However, from sniffing around documentation - this is not the best "recommended" approach to get this working. The argument here is that we now have a credentials file that we would need to manage - this credentials file would potentially be very very powerful and might alter large swathes of our application infrastructure. That wouldn't be ideal.

The second approach for this is to try a relatively new approach: Workload Identity Federation. We are extending our credentials from Google Cloud into Github's auth service via OIDC. (I'm not too sure about the details of how it works - might be worth an entire blog post to try to understand how OIDC works). Our github actions runner would present certain details that only it knows to our Google Cloud account - once all of presented information is correct (e.g. correct github user or correct github repository), we would then authorize the runner to perform all the actions that it needs to do to update our cloud run service.

Here might be some useful resources to find out more on workload identity federation

- https://cloud.google.com/blog/products/identity-security/enabling-keyless-authentication-from-github-actions
- https://cloud.google.com/iam/docs/workload-identity-federation-with-other-providers
- https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect#configuring-the-subject-in-your-cloud-provider
- https://github.com/google-github-actions/auth

The rough gist of steps that I took for setting up CI CD with github actions with workload identity federation is as follows:

- Create a pool for Workload Identity Federation
- Create a service account with the following permissions:
  - Service account token creation
  - Service account OIDC token creation (require confirmation)
  - Cloud Run Developer (permissions to update our Cloud Run registry)
  - Artifact Registry Writer (permissions to update Artifact Registry)
  - Service Account User (without it, we would be unable to replace Cloud Run service surprisingly)
- Grant access to the created pool for the Workload Identity Federation via Service Account. We don't need to save the file - can simply skip the "configuration" file that would inform client libraries how to connect to workload identity
- Save the "subject" for service account mapping to: "repo:hairizuanbinnoorazman/Go_Programming:ref:refs/heads/master"

The second problem is with regards with IAM permissions. Surprisingly, it seems that there is no proper IAM permsissions that we can rely on to push the built docker images to container registries. There are stack overflow posts that mentioned that we can simply add the entire Cloud Storage Admin IAM permissions - but apparently, there doesn't work as expected. There could be some hidden tricks that we would probably need to turn on some configuration on the Google Cloud console. After tweaking around, the only way for me to get docker images into container registry is to use `Editor` permsisions (which is a big no-no here). However, seeing that container registry is already a sunsetting tool, it might be better to simply just move on and proceed to use Artifact Registry - which convenieintly enough, has specific IAM permissions. 

All of the above explanation is mostly for authentication and permissions which can all be summed in a single github actions step.

```yaml
    - id: 'auth'
      name: 'Authenticate to Google Cloud'
      uses: 'google-github-actions/auth@v2'
      with:
        workload_identity_provider: "projects/${{ secrets.GCP_PROJECT_ID }}/locations/global/workloadIdentityPools/hairizuan-personal-github/providers/golang-programming"
        service_account: 'github-actions@${{ secrets.GCP_PROJECT }}.iam.gserviceaccount.com'
```

Another critical step in this workflow would be the step to get docker to have the credentials to be able to push our built docker images into our private artifact registry.

```yaml
    - name: "Docker auth"
      run: |-
        gcloud auth configure-docker asia-southeast1-docker.pkg.dev --quiet   
```

The rest of the steps are not too important to mention here - they are somewhat close to direct commands that we would throw into a terminal such as building docker images and pushing it into the registry as well as using the `gcloud` cli command tool to replace the image being used for our shopping list application.