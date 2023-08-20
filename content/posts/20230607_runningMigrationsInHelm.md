+++
title = "Running database migrations in Helm chart"
description = "Running database migrations in Helm via pre-install chart hooks"
tags = [
    "golang",
    "kubernetes",
]
date = "2023-06-07"
categories = [
    "golang",
    "kubernetes",
]
+++

In many examples for helm charts, the general focus is on the "2nd" day operations of having applications running without too much issues. In the case for usual web developers, that would mean applications handled with kubernetes deployment objects which would run a set number of replicas (or handled via HPA) in the kubernetes cluster.

However, what if the application needs to rely on a database? The one important thing when it comes to applications that rely on database is that we need to have a way to do database migrations. The database migrations could be run via sql scripts or even binaries that run certain set of sql operations to set the initial scheme for the database that we would need to setup for our application.

Let's say our database is in the kubernetes cluster (sometimes, a controversial choice). We can simply run the commands to do the migration from our "deployment" machine. The deployment machine could be some jenkins server that run some shell script that would then do the sql migration on the database. But this would mean that the database migration is something outside application upgrade lifecycle which eventually would mean a harder process to grasp for developers of the application to deal with application upgrades as well as updates to database schema.

Fortunately for us, Helm has a mechanism - lifecycle hook mechanisms. Reference: https://helm.sh/docs/topics/charts_hooks/. We can run certain application of kubernetes objects (e.g Kubernetes jobs) to do certain things that we need to do before our application properly start up - e.g. we can setup a lifecycle helm hook that would set up a Kubernetes job - which in our case would be a database migration job.

Here is an example that we can refer to for explaning an example of how we can do this: https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/basicMigrate

The first part would be deploy a database - a Maria database (a MySQL compatible database)

```bash
helm install -f db-values.yaml mariadb oci://registry-1.docker.io/bitnamicharts/mariadb
```

That would set up a single replica database with a a set amount of resources which we can then have our application rely on.

Our application's helm chart is in the `basicMigrate` folder in the reference url above. The important bit to tap for the helm hooks is the `annotations` on the Kubernetes job. Do note that the database credentials set via environment variables are only for example purposes. It would be better to rely on a proper secret management system to ensure that none of such credentials could be leaked out so easily.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "basicMigrate.fullname" . }}-migrate
  labels:
    {{- include "basicMigrate.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "0"
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  backoffLimit: 5
  activeDeadlineSeconds: 300
  template:
    labels:
      {{- include "basicMigrate.labels" . | nindent 6 }}
    spec:
      serviceAccountName: {{ include "basicMigrate.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      restartPolicy: Never
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          command:
            - "app"
            - "migrate"
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          env:
            - name: DATABASE_USER
              value: "username"
            - name: DATABASE_PASSWORD
              value: "password"
            - name: DATABASE_HOST
              value: "mariadb.default.svc"
            - name: DATABASE_NAME
              value: "application"
```

For the above database migration jobs, we will set up the database migraiton job before the install or upgrade of our application. This is based off `"helm.sh/hook": pre-install,pre-upgrade`.

We can install the helm chart via the following command:

```bash
helm upgrade --install -f app-values.yaml basic ./basicMigrate
```