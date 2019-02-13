# cat endpointDeployServiceKey | base64 -d > endpointDeployServiceKey.json
# cat gaeDeployServiceKey | base64 -d > gaeDeployServiceKey.json
# cat gkeCloudSQLServiceKey | base64 -d > gkeCloudSQLServiceKey.json
# cat gkeDeployServiceKey | base64 -d > gkeDeployServiceKey.json
# cat storageBucketsBackendServiceKey | base64 -d > storageBucketsBackendServiceKey.json

# gsutil cp endpointDeployServiceKey.json gs://resources-practice-secrets-sb
# gsutil cp gaeDeployServiceKey.json gs://resources-practice-secrets-sb
# gsutil cp gkeCloudSQLServiceKey.json gs://resources-practice-secrets-sb
# gsutil cp gkeDeployServiceKey.json gs://resources-practice-secrets-sb
# gsutil cp storageBucketsBackendServiceKey.json gs://resources-practice-secrets-sb

gcloud container clusters get-credentials resources-practice-gke-cluster
kubectl create secret generic django-storage-bucket-credentials --from-file=storageBucketsBackendServiceKey.json
kubectl create secret generic django-endpoint-credentials --from-file=gkeCloudEndpointServiceKey.json

kubectl apply -R -f .


