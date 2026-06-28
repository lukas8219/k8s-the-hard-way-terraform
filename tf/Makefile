gen-keys:
	ssh-keygen -t ed25519 -C "email@email.com" -f ./id_ed25519

ping:
	ansible all -m ping
inventory:
	ansible-inventory --graph --vars
