# Users API benchmark

A small but complete Bones_API application — an `APIRoot`, reflection-enabled
entities and modules whose routes are wired by reflection — benchmarked
end to end against a **memory**, **SQLite** or **PostgreSQL** database.

Unlike the micro-benchmarks in [`../`](../README.md), which isolate single
framework pieces, every operation here is a full in-process `APIRoot.call`:
routing, reflection-bound parameter parsing, security, repository, SQL
generation, the database itself, and entity mapping of the response.

Results from previous runs are in [HISTORY.md](HISTORY.md).

## The API

Entities (`lib/src/api_entities.dart`, `@EnableReflection()`):

| Entity | Fields |
|---|---|
| `Role` | `id`, `name` (unique) |
| `Address` | `id`, `countryCode`, `state`, `city`, `addressLine1`, `zipCode` |
| `User` | `id`, `email` (unique), `name`, `passwordHash`, `enabled`, `creationTime`, `address` → `Address`, `roles` → `List<Role>` (many-to-many) |

Modules (`routes.anyFrom(reflection)` — every public method returning an
`APIResponse` is a route):

| Route | Does |
|---|---|
| `role/create?name=` | Creates a role (idempotent) |
| `role/list` | All roles |
| `user/register?email=&password=&name=&countryCode=&state=&city=[&addressLine1=&zipCode=&roles=a,b]` | Inserts a user, its address and role links |
| `user/byId?id=` | Selects by primary key (with address and roles) |
| `user/update?id=[&name=&enabled=&state=&city=]` | Updates a user and its address |
| `user/remove?id=` | Deletes a user |
| `user/byEmail?email=` | Selects by a unique column |
| `user/byState?state=[&limit=]` | Selects through a join on `address` |
| `user/list[?page=&pageSize=]` | A page of users, ordered by ID |
| `user/count` | Counts users |
| `authenticate?email=&password=` | Login, through `UsersAPISecurity` |

The database is chosen only by the `db` section of the API config
(`sql.memory`, `sqlite` or `postgres`); the tables are created on start
(`generateTables`).

## Running

```bash
cd benchmark/db_users
dart pub get

# Memory (DBSQLMemoryAdapter):
dart run bin/db_users_benchmark.dart --db=memory

# SQLite (a temporary file, deleted at the end):
dart run bin/db_users_benchmark.dart --db=sqlite

# PostgreSQL in a throwaway Docker container (removed at the end):
dart run bin/db_users_benchmark.dart --db=postgres --docker

# PostgreSQL on an existing server:
dart run bin/db_users_benchmark.dart --db=postgres \
  --pg-host=localhost --pg-port=5432 \
  --pg-user=postgres --pg-password=postgres --pg-database=bench
```

For the last form, a local server can be started with:

```bash
docker run --name bench_postgres --rm -p 5432:5432 \
  -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=bench -d postgres
```

**On an existing server, the benchmark deletes every row of the `user` and
`address` tables before seeding** (leftovers from a previous run would skew
the results). Point it at a dedicated database.

### Options

| Option | Default | |
|---|---|---|
| `--db` | `memory` | `memory`, `sqlite` or `postgres` |
| `--users` | `1000` | Users registered before measuring |
| `--duration` | `3s` | Measured time per operation (`3s`, `500ms`) |
| `--warmup` | `1s` | Unmeasured time per operation, before measuring |
| `--ops` | all | Comma-separated subset: `byId,byEmail,byState,list,count,login,register,update,remove` |
| `--sqlite-path` | temp file | SQLite file to use (kept), or `:memory:` |
| `--pg-host`, `--pg-port`, `--pg-user`, `--pg-password`, `--pg-database` | env `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE`, then `localhost`, `5432`, `postgres`, `postgres`, `postgres` | PostgreSQL connection |
| `--docker` | off | Start PostgreSQL in a container (`--pg-*` options then only set the credentials) |
| `--pg-version` | `latest` | `postgres` image tag for `--docker` |
| `--machine` | — | A label for the machine, for the report |
| `--markdown` | off | Print a `HISTORY.md` entry |
| `--json` | — | Save the results as JSON to this file |

## Reading the results

Each operation runs sequentially (one client) for `--duration`, after a
`--warmup`. Every call is timed on its own, so the report gives the mean and
the p50/p95/p99 latencies; `ops/sec` is `1s / mean`.

- Any non-OK response aborts the run: errors are never measured as results.
- Operations run in a fixed order — reads first, then `register`, `update`
  and `remove` — so `register` grows the tables only after the reads.
- `remove` deletes a user registered just for it; that registration is not
  timed.
- Route logging (`APIRouteConfig.log`) is on, as it is by default in an
  application. See [`../README.md`](../README.md#note-on-route-logging) for
  its cost.
- **Memory is not a lower bound.** `DBSQLMemoryAdapter` answers non-ID
  conditions (e.g. `byEmail`) and joins by scanning tables, so it can be
  slower than SQLite. See [`../README.md`](../README.md#where-the-db-and-json-time-goes).
- Throughput depends on the hardware and on what else the machine is doing.
  **Compare only runs from the same machine**, ideally idle and on power.

## Recording a result

Run with `--markdown` (and `--machine` to name the machine), then paste the
printed entry at the top of the entries in [HISTORY.md](HISTORY.md):

```bash
dart run bin/db_users_benchmark.dart --db=sqlite --markdown \
  --machine="MacBook Air M5 16GB"
```

The entry records the date, the `bones_api` version and commit, the machine
(CPU, cores, RAM, OS, Dart) and the DB (with the PostgreSQL server version).

## Development

The entities and modules use `reflection_factory`. After changing them,
regenerate `lib/src/reflection/*.g.dart`:

```bash
dart run build_runner build
```

```bash
dart test            # route tests on memory and SQLite, plus build check
dart test -x build   # without the generated-code check
```
