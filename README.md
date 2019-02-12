# READ BEFORE CLONING #
This repository is for instant set-up of  the Dockerized promotion project

## Make sure that you have knowledge in Google Cloud and Kubernetes before doing this


# Guidelines
* https://docs.google.com/document/d/1YzAWLVGb2V-qBdWpjk7oMMngTgDZ_A8Dc3_sVZlj8Qc/edit#heading=h.xwavkgcfy70o

# Initial deployment
```
$ kubectl apply -R -f .  # to apply ymls in every child folder
```

# Use Google Cloud image to access GKE API
`$ docker run -it google/cloud-sdk bash`
