set -euo pipefail
export ARGOCD_VERSION={{ 'argoproj/argo-cd' | githubversion(argocd_version) }}
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml
{%- if argocd_ingress %}
echo Giving sometime for ingress controller to get ready...
sleep 30
kubectl apply -f ingress.yml
sleep 30
HOST=argocd.{{ cluster | default('testk') }}.{{ domain | default('karmalabs.com') }}
IP=$(kubectl get ingress -n argocd argocd-server-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo You will need to create the following /etc/hosts entry
echo $IP $HOST
URL=http://$HOST
{%- else %}
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
sleep 30
URL=http://$(kubectl get svc -n argocd argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
{%- endif %}

ARGO_PASSWORD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d'/' -f 2)
echo argo ui available at $URL
echo Use Initial Credentials admin/$ARGO_PASSWORD
{% if argocd_download_cli %}
  OS="linux"
  [ -d /Users ] && OS="darwin"
  curl https://github.com/argoproj/argo-cd/releases/download/$ARGOCD_VERSION/argocd-$OS-amd64 > {{ cwd }}/argcod
  chmod u+x {{ cwd }}/argcod
  {% if argocd_password != None %}
    {{ cwd }}/argocd login argocd-server-argocd.apps.{ cluster }}.{{ domain }} --grpc-web --username admin --password $ARGOCD_PASSWORD --insecure
    {{ cwd }}/argocd account update-password --current-password $ARGOCD_PASSWORD --new-password {{ argocd_password }} --grpc-web
    echo Updated admin password to {{ argocd_password }}
  {% endif %}
{% endif %}
