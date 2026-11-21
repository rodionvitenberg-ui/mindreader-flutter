# Tarot Tree backend

Django REST API and Admin for Oracle, Vision, digital decks and their ownership. Python 3.12+ and PostgreSQL 15+ are sufficient. The instructions below use the repository's `backend/` as the working directory.

## Run locally

Start a local database. For Docker, the following creates one isolated PostgreSQL container with a development password and binds it to localhost.

```sh
docker run --rm -d --name tarot-tree-postgres \
  -e POSTGRES_USER=tarot -e POSTGRES_PASSWORD=tarot-dev -e POSTGRES_DB=tarot \
  -p 127.0.0.1:55432:5432 postgres:17-alpine
docker exec tarot-tree-postgres pg_isready -U tarot -d tarot
```

With an existing PostgreSQL instance, substitute its DSN below. Save `.env.example` as `.env` and update the values. Load it into the shell before using Django.

```sh
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r requirements/base.txt
cp .env.example .env
set -a
. ./.env
set +a
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver 127.0.0.1:8000
```

Check [health](http://127.0.0.1:8000/api/v1/health/), [interactive API documentation](http://127.0.0.1:8000/api/v1/docs/) and [Admin](http://127.0.0.1:8000/admin/). The raw schema is at `/api/v1/schema/`. Swagger UI uses its standard CDN assets. With a fresh database the catalog is empty and AI generation reports provider unavailability. A guest can create readings, place digital cards, confirm physical cards manually, and reopen or delete a session. The test suite exercises AI provider responses through test doubles.

Enable `EMAIL_VERIFICATION_ENABLED=true` locally if testing verified access. The development mail backend prints a one-time code to the local server console. It proves only that the local test flow works. See [API.md](API.md) for a guest reading, deck publishing and simulated checkout walkthrough.

## Validation

```sh
DJANGO_ENV=test python manage.py test
DJANGO_ENV=test python manage.py makemigrations --check --dry-run
DJANGO_ENV=test python manage.py spectacular --validate --fail-on-warn --file /tmp/tarot-tree-openapi.yaml
python manage.py prune_backend_data
```

The database user needs permission to create a test database. With an explicitly selected SQLite test backend, `DJANGO_ENV=test TAROT_TEST_SQLITE=1 python manage.py test` runs a smaller verification without PostgreSQL row-lock tests. Use PostgreSQL for integration and CI checks. Start with [BACKEND_ARCHITECTURE.md](BACKEND_ARCHITECTURE.md) for the Flutter mapping and [DEPLOYMENT.md](DEPLOYMENT.md) for production configuration.
