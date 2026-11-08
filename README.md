# EventHub: Polyglot Microservices Platform on Kubernetes / OpenShift
 
EventHub is an event booking platform built as a set of microservices written in different languages. Users can register and log in, browse an event catalog, book a spot, receive an asynchronous notification, and see an AI-generated sentiment summary of event reviews.
 
This repository is my DevOps work on the project: running every service in containers, orchestrating them with Docker Compose, and deploying them to a Kubernetes cluster on the Red Hat OpenShift free trial.
 
> The project skeleton (services and API contract) came from the DEPI program. My contribution is the containerization, orchestration and deployment work described below.
 
## Architecture
 
| Service | Language / Framework | Datastore | Port |
|---|---|---|---|
| `frontend` | React | none | 3000 |
| `services/legacy-catalog-java` | Java (Spring Boot) | MySQL | 8081 |
| `services/auth-service-node` | Node.js (Express) | PostgreSQL | 8082 |
| `services/booking-service-python` | Python (FastAPI) | MongoDB | 8083 |
| `services/notification-worker-go` | Go | none (consumes RabbitMQ) | none |
| `services/ai-insight-service-python` | Python (FastAPI) + Ollama | none (local model) | 8084 |
| `services/analytics-service-python` | Python (FastAPI + background job) | Redis | 8085 |
 
Supporting components: an API gateway (`api-gateway/`), RabbitMQ for asynchronous messaging, and four datastores (MySQL, PostgreSQL, MongoDB, Redis).
 
## What I did (DevOps)
 
- Containerized the multi-language services (Java, Node.js, Python, Go, React).
- Defined the full stack in `docker-compose.yaml` so it starts locally with one command.
- Wrote Kubernetes manifests (Deployments, Services, configuration) and deployed the platform to the Red Hat OpenShift free trial.
- Wired service-to-service communication through the API contract in `docs/API_CONTRACT.md`.
- Investigated and fixed the intentionally broken component in the starter code.
> Note: the OpenShift trial cluster has expired, so the original cluster manifests are no longer stored here.
 
## Repository layout
 
```
api-gateway/   single entry point that routes requests to the services
db-seed/       seed scripts for each database
docs/          architecture notes and API contract
frontend/      React single-page app
infra/         infrastructure and deployment files
services/      the microservices
docker-compose.yaml   run the whole stack locally
```
 
## Run locally
 
```bash
docker compose up --build
```
 
Then open the frontend at <http://localhost:3000>. Each service also has its own `README.md` in `services/<name>/` with instructions for running it natively.
 
## Documentation
 
- `docs/ARCHITECTURE.md`: how the pieces fit together
- `docs/API_CONTRACT.md`: how the services talk to each other
- `docs/PHASE1.md`: scope of this phase
## Tech stack
 
Docker, Docker Compose, Kubernetes, Red Hat OpenShift, RabbitMQ, MySQL, PostgreSQL, MongoDB, Redis, React, Spring Boot, Node.js, FastAPI, Go
 

