+++
title = "Trying out Google Cloud Workflows"
description = "Serverless with Google Cloud Workflows and Google Cloud Run"
tags = [
    "golang",
    "google-cloud",
]
date = "2022-10-10"
categories = [
    "golang",
    "google-cloud",
]
+++

Over the recent weekends, I've decided to take a gander and try another "serverless" tool called Google Cloud Workflows. The tool's appeal is to be able coordinate a bunch of services in order to achieve a particular goal. The coordination effort (or workflow) can easily get pretty complex -> one way would be to script but if we want to have the capability to have the button to run the entire workflow from start to end with logging in place as well as capability to run the workflow based on particular triggers.

Let's have an example workflow that we intend to develop as follows:

![analysis_workflow](/20221010_tryingOutCloudWorkflows/analysis_workflow.png)

The workflow would involve the following:

- Run an analysis on a csv file that is stored in Google Cloud Storage
- Generate a chart image out of the analysis
- Generate a pdf report that is to be sent to our "clients"
- Send email at the end

Each of these steps can be automated accordingly. We will go into each of the steps one at a time.

## Setting up a fake Email Server

Notice that at the end, we would be sending an email to a "user". For testing purposes, it wouldn't make sense to get a email service to send email. In order to for us to be able to send fake emails for testing purposes, we can utilize a tool called [MailHog](https://github.com/mailhog/MailHog). If we're happy with the workflow, we can add code to the "send email" service to be able to utilize an actual email sending service such as SendGrid.

To run the MailHog, we can simply create a small virtual machine (we're only deploying a MailHog that would store the mails in memory - so we would need the instance to be permanent).

To install MailHog on the server, we would need to run the following lines (or you can refer instructions on the MailHog's github Readme):

```bash
sudo apt-get -y install golang-go
go get github.com/mailhog/MailHog
```

We would need MailHog to run continuously - if the mail server goes down, we would need to be restarted. One way to do this would be to have it be managed by Systemd. The mail server binary would need to be copied to the appropiate location so that it can be managed by systemd. We would need to run the following commands:

```bash
sudo useradd mailhog
cp ~/go/bin/MailHog /usr/local/bin/mailhog/MailHog
```

Naturally, we would need to ensure that the service has passwords. For testing purposes, we can add the following in the file: `/usr/local/bin/mailhog/auth`. The username and password is both "test". We would need to have our "send email" service to send said auth when accessing our MailHog mail server.

```
test:$2a$04$V9Wl7HyqjdXS3FBbc0juGePhjf1GKkblJSqSt3HNC5fA7HzXA/8ua
```

We would need then add the following file: `/etc/systemd/system/mailhog.service`

```
[Unit]
Description=Mailhog
Requires=network-online.target
After=network-online.target

[Service]
User=mailhog
Group=mailhog
Restart=on-failure
ExecStart=/usr/local/bin/mailhog/MailHog  -auth-file /usr/local/bin/mailhog/auth
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
```

To get our service started, the following commands would need to be run:

```bash
sudo systemctl daemon-reload
sudo systemctl enable mailhog
sudo systemctl start mailhog
```

After this, if all goes well, we would get the following status:

```bash
$ sudo systemctl status mailhog

● mailhog.service - Mailhog
     Loaded: loaded (/etc/systemd/system/mailhog.service; enabled; vendor preset: enabled)
     Active: active (running) since Sun 2022-10-09 21:21:07 UTC; 23h ago
   Main PID: 10835 (MailHog)
      Tasks: 6 (limit: 2355)
     Memory: 19.6M
        CPU: 1.940s
     CGroup: /system.slice/mailhog.service
             └─10835 /usr/local/bin/mailhog/MailHog -auth-file /usr/local/bin/mailhog/auth

Oct 10 20:35:07 mailhog MailHog[10835]: [APIv1] KEEPALIVE /api/v1/events
Oct 10 20:36:07 mailhog MailHog[10835]: [APIv1] KEEPALIVE /api/v1/events
```

With that, one piece of our workflow is now up and running. We would now need to look at deploying the bunch of services that would handle the rest of our workflow.

In order to stick to the theme of ensuring that our workflow is as "serverless" as possible, we would run most of workloads within Cloud Run services.

## Run analysis

For our sample workflow, we can create a simple Golang services (ideally, Python would generally be a better choice here since it has better library support when it comes to analysis work). Since this is just a sample workflow just for trying out the Cloud Workflow purpose, the algorithms being coded in here is pretty simple and it is assumed that the data being provided for analysis is small enough such that it wouldn't take too much time for the algorithm to run across the dataset.

This service would involves the following steps:

- Retrieve data (formatted as csv) from Google Cloud Storage
- Run some quick validation logic to make sure that the csv file is ok to be worked with
- Run algorithm that would summarize the dataset that is being provided
- Return output to the caller (which in our case, would be the Cloud Workflow tool)

The example code is available in the following folder in the github repo. It also includes the Dockerfile that would be used to build out the container that would hold the binary that would run the analysis work.

Reference: https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/runAnalysis

## Make charts

This would be the next of the workflow, which is to make the charts out of the summary provided from the analysis of the previous step. Charts are generally pretty complex to handle - most charts are actually targetted for the frontend, there isn't much proper image libraries that would provide the functionality to create chart images pretty easily. Hence, the easiest approach is to just use one of those frontend chart libraries (which looks quite decent as well) and then just do a screenshot of the generated chart.

This service would involve the following:

- Receive the input via a POST request of the chart properties
- Render the chart via one of the routes in the application
- Use chromium browser to screenshot the rendered chart in a image file
- Save the image file into GCS
- Output out of the service the name of image file in GCS

Reference: https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/makeCharts

## Create Report

Naturally, part of business processes would always involve sending analysis in reports. This is a service that would accept the analysis from previous processes and embed it in all a PDF document.

This service would involve the following:

- Receive input of how to produce the report via a POST request
- Pull the markdown file that is used for templating the report from GCS
- Pull chart images for the report from GCS
- Generate the PDF that would be "sent" to the "client"
- Save the PDF report into GCS
- Output the name of the PDF report (for future step reference)

Reference: https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/createReport

## Send Email

This would be the last step of the entire journey; someone always need to be at the end of the entire analysis lifecycle. Analysis are usually consumed by requiring users to access some form of dashboard or by have said analysis sent to them straight into their email inbox

This service would involve the following:

- Receive input of what report is to be sent
- Service would pull report that is to be sent from GCS
- Service would send the report via SMTP to email server (which in this is MailHog)

Reference: https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/sendEmail

## Actually setting up the workflow

The last step would be to coordinate all of the above services together. Technically, we can kind of write up some scripts which we would need to manually go in and run but with scripts, they come with their own host of problems:

- If script to coordinate the services is only on a "someone's" work computer; if any issue comes about, we won't be able to resolve it easily
- If it's on that one person's work computer, then its somewhat troublesome to ensure that the person's work computer is up and running and would run the script with no issue when it is required for us to run it. We would need ways to properly monitor the running of this "script" to ensure that it's completed successfully and in time to meet business requirements
- Not sure if script involves managing any state changes. In the case of the current example, we don't need to store state but imagine if there is a need for it; we'll need to ensure that it should be backed-up (just in case)

For the above workflow, we can program it like so - a somewhat linear workflow:

```
main:
  params: [args]
  steps:
    - initializeWorkflow:
        assign:
          - sourceData: ${args.sourceData}
          - sendEmail: ${args.sendEmail}
          - reportTitle: ${args.reportTitle}
          - reportDescription: ${args.reportDescription}
    - runAnalysis:
        call: http.post
        args:
          url: https://run-analysis-xxxxx.a.run.app/run-analysis
          body:
            source_data: ${sourceData}
        result: runAnalysisResults          
    - viewRunAnalysisBody:
        call: sys.log
        args:
          text: ${runAnalysisResults.body}
    - decodeRunAnalysisResults:
        call: json.decode
        args:
          data: ${runAnalysisResults.body}
        result: runAnalysisResultsBody
    - createChartImage:
        call: http.post
        args:
          url: https://make-charts-xxxxx.a.run.app/screenshot
          body:
            title: Sales Report 
            x_axis_title: Product Names
            labels: ${runAnalysisResultsBody.products}
            data: ${runAnalysisResultsBody.revenue}
        result: createChartImageResults
    - decodeChartImageResults:
        call: json.decode
        args:
          data: ${createChartImageResults.body}
        result: createChartImageResultsBody
    - zzz:
        call: sys.log
        args:
          text: ${createChartImageResults.body}
    - createReport:
        call: http.post
        args:
          url: https://create-report-xxxxx.a.run.app/create-report
          body:
            title: ${reportTitle}
            description: ${reportDescription}
            template_file_name: haha.md
            image: ${createChartImageResultsBody.filename}
        result: createReportResults
    - decodeCreateReport:
        call: json.decode
        args:
          data: ${createReportResults.body}
        result: createReportResultsBody
    - sendEmailDecider:
        switch:
          - condition: ${sendEmail == false}
            steps:
              - earlyTerminatedStep:
                  return: ${"Email is not sent. Please check " + createReportResultsBody.generated_report_name + " in GCS"}
    - sendEmail:
        call: http.post
        args:
          url: https://send-email-xxxxx.a.run.app/send-email
          body:
            to: test@test.com
            subject: This is another test
            body: Report Generated
            report_filename: ${createReportResultsBody.generated_report_name}
    - finalStep:
        return: "Report Generated. Please request receiver to check his email"
```

To deploy it, we can run the following command:

```bash
gcloud workflows deploy myFirstWorkflow --source=zzz.yaml 
```

And that would have the workflow pop into existance in the Google Cloud Project of our choice.

## Conclusion

The cloud workflow tool is definitely interesting tool to try out but throughout the entire experience of "attempting" to use it, it does seem like a lot more time was spent in order to build out the services that would be consumed by the cloud workflows tool. More complex workflow tools would require more intricate services to be developed and hence, more effort is needed before we get to try more complicated features in Cloud Workflows products.

There are some interesting things that might be worth thinking/trying out in the future if I manage to thing of the appropiate use-cases:

- Parallel steps in workflow
- Workflows calling other sub-workflows
- Retry of particular steps in workflows
- Having workflows await for human responses