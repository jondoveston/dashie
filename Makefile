APP = dashie_app

.PHONY: all
all: up

.PHONY: bash
bash:
	docker-compose run $(APP) bash

.PHONY: exec
exec:
	docker-compose exec $(APP) bash

.PHONY: fix_perms
fix_perms:
	sudo chown -R $(USER):$(USER) .

.PHONY: clean
clean: fix_perms
	echo log/*.log | xargs -n1 cp /dev/null

.PHONY: pull
pull:
	docker-compose pull

.PHONY: build
build: stop
	docker-compose build --force-rm --no-cache --pull

.PHONY: stop
stop:
	docker-compose stop
	docker-compose rm -fs

.PHONY: up
up:
	docker-compose up --remove-orphans $(APP)

.PHONY: bundle
bundle:
	docker-compose run $(APP) bundle

.PHONY: console
console:
	docker-compose run $(APP) irb
