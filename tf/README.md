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

### How to
```bash
source .venv/bin/activate
gcloud init
gcloud auth application-default login
make gen-ssh-keys
make tf
make ping
make playbook
# or simply make
```

It will Auth into GCP, Generate SSH keys locally, apply TF and call Ansible
