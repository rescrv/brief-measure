# Brief Measure

Brief Measure is an open source mood and symptom tracking app for people with BP1 with psychotic
features or Schizophrenia.  It is adapted from questionnaires commonly given to patients based upon
the author's memory.

Most questions have been adapted to the following scale:
- No Symptoms:  The symptoms are not present.
- Noticed:  The symptoms were noticed but there was no impact on daily living.
- Impactful:  The symptoms are impacting daily life, but may not be noticeable to others.
- Debilitating:  The symptoms are impacting daily life in a significant way.

The goal is not to perfectly answer the questions.  The goal is to have _an_ answer and provide it
consistently each day and track trends.

It comes in pieces:  An iPhone app available in the App Store as "Brief Measure" and a backend.
Host the backend on an HTTPS URL and point the Brief Measure settings to point to that URL.  As can
be seen in the brief-measure/ directory, the only thing stored is the API key, and a string of ten
digits 1-4 inclusive.  Forgetting an API key (a pre-requisite to generating a new one) causes the
server to lose all data stored for that key.  This is by design to ensure data sovereignty.

GitHub-based builds are available via GitHub-actions-based builders at
ghcr.io/rescrv/brief-measure-migrate-up and ghcr.io/rescrv/brief-measure-serve.  If you run
kubernetes you can run the former as an init-container to migrate the database and the latter as the
main container.  Here's my kustomize:

```ignore
apiVersion: v1
kind: Namespace
metadata:
  name: briefmeasure
---
apiVersion: v1
kind: Secret
metadata:
  name: brief-measure-db-secret
  namespace: briefmeasure
type: Opaque
stringData:
  DATABASE_URL: <put the database url here>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: briefmeasure
  namespace: briefmeasure
spec:
  replicas: 1
  selector:
    matchLabels:
      app: briefmeasure
  template:
    metadata:
      labels:
        app: briefmeasure
    spec:
      initContainers:
      - name: brief-measure-migrate-up
        image: ghcr.io/rescrv/brief-measure-migrate-up:76670296f0ec8ac407745286cf0453d1773fdcfd
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: brief-measure-db-secret
              key: DATABASE_URL
      containers:
      - name: brief-measure-serve
        image: ghcr.io/rescrv/brief-measure-serve:76670296f0ec8ac407745286cf0453d1773fdcfd
        env:
        - name: BIND_ADDR
          value: 0.0.0.0:3000
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: brief-measure-db-secret
              key: DATABASE_URL
        ports:
        - containerPort: 3000
---
apiVersion: v1
kind: Service
metadata:
  name: briefmeasure-service
  namespace: briefmeasure
spec:
  type: NodePort
  ports:
    - name: http
      port: 3000
      targetPort: 3000
      nodePort: 32767
      protocol: TCP
  selector:
    app: briefmeasure
```

I recommend auditing the code at a version and hard-coding the image tags as I've done here.  If
you're running microk8s (available on Ubuntu), this will listen on the public IP of your host on
port 32767.
