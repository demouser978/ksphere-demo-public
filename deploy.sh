kubectl kudo init --dry-run -o yaml | kubectl delete -f -
kubectl kudo init --wait

kubectl kudo install zookeeper --instance=zk --version=0.2.0

until [ $(kubectl get pods --selector=kudo.dev/instance=zk --field-selector=status.phase=Running | grep -v NAME -c) -eq 3 ]; do
  sleep 1
  kubectl get pods --selector=kudo.dev/instance=zk
done

kubectl kudo install kafka --instance=kafka -p ZOOKEEPER_URI=zk-zookeeper-0.zk-hs:2181,zk-zookeeper-1.zk-hs:2181,zk-zookeeper-2.zk-hs:2181 --version=1.1.0

until [ $(kubectl get pods --selector=kudo.dev/instance=kafka --field-selector=status.phase=Running | grep -v NAME -c) -eq 3 ]; do
  sleep 1
  kubectl get pods --selector=kudo.dev/instance=kafka
done

kubectl create -f https://raw.githubusercontent.com/kudobuilder/operators/master/repository/kafka/docs/v1.1/resources/service-monitor.yaml

# Import the Grafana dashboard from https://raw.githubusercontent.com/kudobuilder/operators/master/repository/kafka/docs/v1.1/resources/grafana-dashboard.json

kubectl create -f "https://github.com/minio/minio-operator/blob/master/examples/minioinstance-with-external-service.yaml?raw=true"

until [ $(kubectl get pods --selector=app=minio --field-selector=status.phase=Running | grep -v NAME -c) -eq 4 ]; do
  sleep 1
  kubectl get pods --selector=app=minio
done

kubectl kudo install cassandra --instance=cassandra -p NODE_CPUS=2000m -p NODE_MEM=2048 --version=0.1.0

until [ $(kubectl get pods --selector=kudo.dev/instance=cassandra --field-selector=status.phase=Running | grep -v NAME -c) -eq 3 ]; do
  sleep 1
  kubectl get pods --selector=kudo.dev/instance=cassandra
done

# brew install minio/stable/mc

kubectl get svc minio-service -o yaml | sed 's/ClusterIP/LoadBalancer/' > minio-service.yaml
kubectl replace -f minio-service.yaml

until [[ $(kubectl get svc minio-service --output jsonpath={.status.loadBalancer.ingress[*].hostname}) ]]; do sleep 1; done

until nslookup $(kubectl get svc minio-service --output jsonpath={.status.loadBalancer.ingress[*].hostname}); do
  sleep 1
done

mc config host add minio http://$(kubectl get svc minio-service --output jsonpath={.status.loadBalancer.ingress[*].hostname}):9000 minio minio123
mc admin config set minio notify_kafka:1 brokers="kafka-kafka-0.kafka-svc:9092" topic="minio"
mc admin service restart minio

minio=$(kubectl get svc minio-service --output jsonpath={.status.loadBalancer.ingress[*].hostname})
sed "s/MINIOEXTERNALENDPOINT/${minio}/" ../ksphere-demo-gitops/photos/application.yaml.tmpl > ./application.yaml.tmpl
mv ./application.yaml.tmpl ../ksphere-demo-gitops/photos/application.yaml.tmpl

sleep 10

mc mb minio/images
mc event add minio/images arn:minio:sqs::1:kafka --suffix .jpg
mc event list minio/images

cd ../ksphere-demo-gitops
git commit -a -m "Updating the external Minio endpoint"
git push
cd ../ksphere-demo

#helm delete --purge dispatch
#kubectl delete namespace dispatch
dispatch init --watch-namespace=dispatch
dispatch serviceaccount create dispatch-sa
dispatch login github --user ${GITHUB_USERNAME} --token ${GITHUB_TOKEN} --service-account dispatch-sa
rm -f dispatch.pem
ssh-keygen -t ed25519 -f dispatch.pem -q -N ""
dispatch login git --private-key-path dispatch.pem --service-account dispatch-sa
docker login -u ${DOCKER_USERNAME} -p ${DOCKER_PASSWORD}
dispatch login docker --service-account dispatch-sa
dispatch gitops creds add https://github.com/${GITHUB_USERNAME}/ksphere-demo-gitops --username=${GITHUB_USERNAME} --token=${GITHUB_TOKEN}
dispatch create repository --service-account dispatch-sa
dispatch gitops app create ksphere-demo-map --repo=https://github.com/${GITHUB_USERNAME}/ksphere-demo-gitops --path=map --service-account dispatch-sa
dispatch gitops app create ksphere-demo-flickr --repo=https://github.com/${GITHUB_USERNAME}/ksphere-demo-gitops --path=flickr --service-account dispatch-sa
dispatch gitops app create ksphere-demo-photos --repo=https://github.com/${GITHUB_USERNAME}/ksphere-demo-gitops --path=photos --service-account dispatch-sa

# kubectl -n dispatch edit ingresses dispatch-tekton-dashboard and remove the auth annotations
# kubectl -n dispatch edit ingresses dispatch-argo-cd and remove the auth annotations
