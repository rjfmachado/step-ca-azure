az group create --name stepca --location westeurope
az aks create --name stepca --location westeurope --resource-group stepca --no-ssh-key
az aks get-credentials --name stepca --resource-group stepca

helm repo add smallstep https://smallstep.github.io/helm-charts/

//in your client, install the step client to generate a helm values yaml
wget https://dl.step.sm/gh-release/cli/docs-cli-install/v0.20.0/step-cli_0.20.0_amd64.deb
sudo dpkg -i step-cli_0.20.0_amd64.deb

step ca init --helm > values.yaml

// how to handle certificates, secrets in values.yaml

echo "password" | base64 > password.txt
helm install -f values.yaml \
--set inject.secrets.ca_password=$(cat password.txt) \
--set inject.secrets.provisioner_password=$(cat password.txt) \
--set service.targetPort=9000 \
step-certificates smallstep/step-certificates
