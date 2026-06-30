gen-keys:
	ssh-keygen -t ed25519 -C "email@email.com" -f ./id_ed25519

tf:
	terraform init
	terraform apply -auto-approve
ping:
	ansible all -m ping
inventory:
	ansible-inventory --graph --vars
playbook:
	ansible-playbook playbook.yaml
