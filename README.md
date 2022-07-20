# Labrador-maison
Home lab, but in French 

The goal is to have my entire homelab config live in a repository so I can tear it down and rebuild it easily, provided I have a working computer laying around. I plan to force myself to re-format my computers at regular intervals to simulate crashes to test how quickly I can get back up to a working state that is exactly as it was before.

All applications & utilities run behind a container friendly reverse proxy using [Traefik](https://doc.traefik.io/traefik/). I have a non-network facing home server that is configured to be its own certificate authority, thanks to this incredibly helpful guide of [Jamie Nguyen](https://jamielinux.com/docs/openssl-certificate-authority/sign-server-and-client-certificates.html).

The reverse proxy uses my self-signed certs because I like pain (and learning). All applications are behind traefik, using Docker labels to dynamically configure configure routers & load balancers this part is easy and fun !. Traefik continously watches the Docker daemon and adapts to everything that comes and goes.

My internal DNS is a pi-hole where I configure all new entries manually. Not very efficient but suitable for the time being.

# Apps

All apps are configured with `docker-compose` files and need the reverse proxy + a DNS entry in my pi-hole to work properly.  
    
- CI/CD pipelines using the amazing [Concourse CI](https://concourse-ci.org/docs.html)
- Container registry (self-hosted) with [docker-registry](https://docs.docker.com/registry/)  and a fancy-shmancy [registry-ui](https://github.com/Joxit/docker-registry-ui)
- Container log viewer in the browser with [dozzle](https://github.com/amir20/dozzle)


Planned:
- Self-hosted renovate for automatic updates (docker images, app packages, etc.)
- My apps (still private atm)
- At some point, K3S or Docker Swarm, but probably K3S
- Plan more stuff
