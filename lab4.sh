#Task - 1 :
export REGION="us-east4"
export ZONE="us-east4-b"

gcloud compute networks create griffin-dev-vpc --subnet-mode custom

gcloud compute networks subnets create griffin-dev-wp --network=griffin-dev-vpc --region $REGION --range=192.168.16.0/20

gcloud compute networks subnets create griffin-dev-mgmt --network=griffin-dev-vpc --region $REGION --range=192.168.32.0/20

#Task - 2 :

gcloud compute networks create griffin-prod-vpc --subnet-mode custom

gcloud compute networks subnets create griffin-prod-wp --network=griffin-prod-vpc --region $REGION --range=192.168.48.0/20

gcloud compute networks subnets create griffin-prod-mgmt --network=griffin-prod-vpc --region $REGION --range=192.168.64.0/20


#Task - 3 : 


gcloud compute instances create bastion --network-interface=network=griffin-dev-vpc,subnet=griffin-dev-mgmt  --network-interface=network=griffin-prod-vpc,subnet=griffin-prod-mgmt --tags=ssh --zone=$ZONE --machine-type=e2-medium

gcloud compute firewall-rules create fw-ssh-dev --source-ranges=0.0.0.0/0 --target-tags ssh --allow=tcp:22 --network=griffin-dev-vpc

gcloud compute firewall-rules create fw-ssh-prod --source-ranges=0.0.0.0/0 --target-tags ssh --allow=tcp:22 --network=griffin-prod-vpc


#Task - 4 : 
gcloud sql instances create griffin-dev-db \
    --database-version=MYSQL_8_0 \
    --region=$REGION \
    --root-password='!@QWaszx12'
	
gcloud sql connect griffin-dev-db --user=root --quiet

CREATE DATABASE wordpress;
CREATE USER "wp_user"@"%" IDENTIFIED BY "stormwind_rules";
GRANT ALL PRIVILEGES ON wordpress.* TO "wp_user"@"%";
FLUSH PRIVILEGES;

exit

#Task - 5 :

gcloud container clusters create griffin-dev \
  --network griffin-dev-vpc \
  --subnetwork griffin-dev-wp \
  --machine-type e2-standard-4 \
  --num-nodes 2  \
  --zone $ZONE


gcloud container clusters get-credentials griffin-dev --zone $ZONE

#Task - 6 : 
cd ~/
gsutil cp -r gs://cloud-training/gsp321/wp-k8s .

cat > wp-k8s/wp-env.yaml <<EOF_END
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: wordpress-volumeclaim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 200Gi
---
apiVersion: v1
kind: Secret
metadata:
  name: database
type: Opaque
stringData:
  username: wp_user
  password: stormwind_rules

EOF_END

cd wp-k8s

kubectl create -f wp-env.yaml

gcloud iam service-accounts keys create key.json \
    --iam-account=cloud-sql-proxy@$GOOGLE_CLOUD_PROJECT.iam.gserviceaccount.com
kubectl create secret generic cloudsql-instance-credentials \
    --from-file key.json
	
#Task - 7 : 

INSTANCE_ID=$(gcloud sql instances describe griffin-dev-db --format='value(connectionName)')




cat > wp-deployment.yaml <<EOF_END
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  labels:
    app: wordpress
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wordpress
  template:
    metadata:
      labels:
        app: wordpress
    spec:
      containers:
        - image: wordpress
          name: wordpress
          env:
          - name: WORDPRESS_DB_HOST
            value: 127.0.0.1:3306
          - name: WORDPRESS_DB_USER
            valueFrom:
              secretKeyRef:
                name: database
                key: username
          - name: WORDPRESS_DB_PASSWORD
            valueFrom:
              secretKeyRef:
                name: database
                key: password
          ports:
            - containerPort: 80
              name: wordpress
          volumeMounts:
            - name: wordpress-persistent-storage
              mountPath: /var/www/html
        - name: cloudsql-proxy
          image: gcr.io/cloudsql-docker/gce-proxy:1.33.2
          command: ["/cloud_sql_proxy",
                    "-instances=$INSTANCE_ID=tcp:3306",
                    "-credential_file=/secrets/cloudsql/key.json"]
          securityContext:
            runAsUser: 2  # non-root user
            allowPrivilegeEscalation: false
          volumeMounts:
            - name: cloudsql-instance-credentials
              mountPath: /secrets/cloudsql
              readOnly: true
      volumes:
        - name: wordpress-persistent-storage
          persistentVolumeClaim:
            claimName: wordpress-volumeclaim
        - name: cloudsql-instance-credentials
          secret:
            secretName: cloudsql-instance-credentials

EOF_END

kubectl create -f wp-deployment.yaml
kubectl create -f wp-service.yaml

#Task - 8 : 

EXTERNAL_IP=$(kubectl get services wordpress -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
	gcloud compute instances list

    gcloud monitoring uptime-check create wordpress_uc \
      --ip-address $EXTERNAL_IP \
      --check-interval 60s \
      --protocol HTTP \
      --resource-type public_ip
	  
	gcloud monitoring uptime create wordpress_uc \
      --ip-address $EXTERNAL_IP \
      --check-interval 60s \
      --protocol http \
      --resource-type uptime-url
	

#task - 9 :

sudo apt -y install jq

echo "export USERID2="Username2"" >> ~/.bashrc

gcloud config list project

echo "export PROJECTID2="qwiklabs-gcp-03-7adee6343238"" >> ~/.bashrc

. ~/.bashrc
gcloud projects add-iam-policy-binding $PROJECTID --member user:$USERID2 --role=roles/editor


