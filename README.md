# Helm Chart for automatically renewing TLS certificate

This a helm chart for obtaining and automatically renewing TLS certificate on the NERSC spin platform. Before installation, you will need:

1. an existing or a new namespace of a Spin project;
2. install `kubectl` and `helm`;
3. obtain the `kubeconfig` from the Spin cluster where your project runs (either the "development" or "production" cluster).

## Create a new namespace in Spin

1. Login to rancher2.spin.nersc.gov;
2. click the cluster name (as of May 12, 2024, either "development" or "production");
3. click "Project/Namespaces" on the sidebar, click "Create Namespace" beside your chosen project.

## Install `kubectl`

For up-to-date information, please refer to the [official documentation](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/).

1. Obtain `kubectl` via `curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl`;
2. Set the downloaded `kubectl` to be executable (`chmod +x kubectl`);
3. move `kubectl` to its desired destination (e.g. `mv kubectl $HOME/bin/kubectl`);
4. parent directory of `kubectl` should be include in your `PATH` environment variable, add it if needed (e.g. `export PATH=$HOME/bin:$PATH`)

## Install `helm`

For up-to-date information, please refer to the [official documentation](https://helm.sh/docs/intro/install/).

1. Download your [desired version](https://github.com/helm/helm/releases)
2. Unpack it (e.g. `tar -zxvf helm-v3.0.0-linux-amd64.tar.gz`)
3. Find the helm binary in the unpacked directory, and move it to its desired destination (e.g. `mv linux-amd64/helm $HOME/bin/helm`);
4. parent directory of `helm` should be include in your `PATH` environment variable, add it if needed (e.g. `export PATH=$HOME/bin:$PATH`)

## Download `KUBECONFIG`

KUBECONFIG is a YAML file containing the deteails of the k8s cluster, such as its address, and your own authentication credentials. It can be downloaded from the Spin.

1. Login to rancher2.spin.nersc.gov;
2. click the cluster name (as of May 12, 2024, either "development" or "production");
3. hover the mouse pointer over the "page" icon on the top right of the page, it should say "Download KubeConfig", click it to download.
4. create `$HOME/.kube` directory if not existing, and save the downloaded file to `$HOME/.kube/config`; alternatively, you can set the `KUBECONFIG` environment variable to the path to the downloaded YAML file.

## Create `KUEBCONFIG`secret

Using `kubectl`, create a `kubeconfig` secret in the targeted namespace (replace `<targeted_namespace>` and `<path to kubeconfig>` accordingly):

```bash
kubectl -n <targeted_namespace> create secret generic kubeconfig --from-file=kubeconfig=<path to kubeconfig>
```

## Install the helm chart

This helm chart takes consideration of two different usage cases. The installation procedure is different.

### Case 1

In this case, the following conditions must be met:

1. The namespace already has a running web server;
2. The web server has its web root on a shared persistent volume;
3. The ingress is not defined for the web server, if so, delete it first;
4. you have a CNAME record points to `<ingress>.<namespace>.<cluster>.svc.spin.nersc.gov`. 

#### Clone the repo

Clone this repository with `git clone https://github.com/dingp/spin-acme.git`.

The directory tree looks like the following:

```
spin-acme
├── charts
├── Chart.yaml
├── README.md
├── templates
│   ├── certsecret.yaml
│   ├── cronjob.yaml
│   ├── _helpers.tpl
│   ├── ingress.yaml
│   ├── service.yaml
│   ├── webpvc.yaml
│   └── websrv.yaml
├── values-existing-websrv.yaml
└── values.yaml

2 directories, 11 files
```

#### Customize values for chart installation

Make a copy of `values.yaml`, and modify it by setting:
- `<uid>`
- `<gid>`
- `<domain>`
- `<email>`
- `<port>`
- `<ingress_name>`
- `<cluster>` (can be `development.svc.spin.nersc.org` or `production.svc.spin.nersc.org`)
- `existing-websrv`
- `pvc-existing-webroot` 
- change `webServer.existing` field from `false` to `true`

#### Install the chart

Install the helm chart with the following command. Replace `<namespace>` with your namespace. `acmecron` is a release name for which you can name your own.

```bash
helm install -n <namespace> -f modified-values.yaml acmecron ./spin-acme
```

#### Inspect the installation

The results of this installation are:

1. A self-generated TLS certificate saved into a secret named `tls-cert`;
2. A new ingress in the namespace, with rules for each of the domains, including the default Spin domain, pointing to the existing web server and its http port; the ingress will also use the self-generated certificate for all the domains;
3. A cronjob which runs every two months to reuqest/renew a TLS certificate, and repalce the self-generated TLS certificate with it. The requested certificate will include all the listed domains in the ingress.

#### Post installation setup 

Once the chart is installed, you can trigger the cronjob manually once to request and use the initial certificate. To trigger the cronjob, you can use the webUI, select "Workloads" -> "CronJobs", click the three dots beside the cronjob, and choose "Run Now".

Alternatively, you can trigger the CronJob via `kubectl`. 

```bash
# get the cronjob name
kubectl get cronjob -n <namespace>
# replace cronjob_name, and job_name below
kubectl create job --from=cronjob/<cronjob_name> <job_name>
```
It is recommended to "View Logs" while the triggered job is running, and verify the procedure is completed successfully.

### Case 2

This case requires the followings conditions to be met:

1. There is no web server running in the namespace;
2. Or there is a running web server, but there's no write access to the running webserver's web root directory;
3. The ingress is not defined for the web server, if so, delete it first, assuming the ingress will be named `myingress`;
4. you have a CNAME record points to `myingress.mynamespace.development.svc.spin.nersc.gov`. 

This is applicatable to the usage cases like:
1. You are running web service which does not have a writable web root directory, e.g. a REST API server;
2. You have a web server, but serving a read-only directory (e.g. a directory mounted from CFS).

#### Installation and inspection

Similar as *Case 1* above, but change the following in the copied `values.yaml`:
- `<uid>`
- `<gid>`
- `<domain>`
- `<email>`
- `<port>` to `8080`
- `<ingress_name>`
- `<cluster>` (can be `development.svc.spin.nersc.org` or `production.svc.spin.nersc.org`)

Different than *Case 1*, this installation of the chart will result in:

1. A deployment of a simple web server, running on port 8080 internally;
2. A new ingress in the namespace, pointing all of the domains, including the default Spin domain, to the newly created web server and its port 8080.

#### Post installation setup

Follow instructions in Case 1 to trigger the initial run of the cronjob, view logs while it's running, and verify the initial request is completed successfully. Same as in Case 1, once the TLS certificate is obtained, it will replace original self-generated certificate.

At this point, you will need to modify the ingress to point it to your API server, or your existing web server (for which we didn't have write access to its webroot).

During, the future cronjob runs, your modified ingress will be saved first, changed briefly to the simple web server's port 8080, restored back once the certificate is renewed.

### Upgrade or uninstall the chart

If you made changes to `values.yml`, you can `upgrade` the installed chart by:

```bash
helm upgrade -n <namespace> -f modified-values.yaml <release-name> ./spin-acme
```
Note the `<release-name>` should be the same one you used during initial installation. In the Case 2, if you've made modifications to the ingress after the initial Cronjob run, the modifications will be lost after upgrade, and will need to be re-applied. It's recommended that you backup the YAML for the ingress before the upgrade.

In case you want to uninstall the chart, you can do so by:

```bash
helm uninstall --namespace <namespace> <release-name>
```
Similarly, the `<release-name>` should be the same one you used during initial installation.