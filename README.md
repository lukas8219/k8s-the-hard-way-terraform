## SRE Challenges

## Kubernetes The Hard Way Made Even Harder

The idea is to trasnform Kelsey Hightowwer KTHW into something fully automated
- Google Cloud Platform
- Terraform
- Ansible


## prerequesites
- kubectl (for n0w)
- openssl
- python3.10
- gcloud
- make

### How to
```bash
export ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
source .venv/bin/activate
gcloud init
gcloud auth application-default login
make gen-keys
make tf
make galaxy
make ping
make playbook
# or simply make
```

It will Auth into GCP, Generate SSH keys locally, apply TF and call Ansible
