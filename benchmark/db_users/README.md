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
| `--repeat` | `1` | Measured rounds of `--duration` per operation: the median round is reported, with the range of all of them |
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
- **PostgreSQL varies between rounds of the same code**, by more than most
  changes being measured (e.g. `user/list` from ~300 to ~580 ops/sec).
  Every call waits on the database several times, and while it waits the
  OS lowers the CPU's clock or moves the thread to an efficiency core
  (Apple Silicon; Docker Desktop's VM threads too), so even the
  framework's CPU work between queries slows down. Use `--repeat 5` (or
  more) and compare medians; the `rounds` range shows the spread. SQLite and
  memory calls never wait, and don't vary this way.

## Recording a result

Run with `--markdown` (and `--machine` to name the machine), then paste the
printed entry at the top of the entries in [HISTORY.md](HISTORY.md):

```bash
dart run bin/db_users_benchmark.dart --db=sqlite --markdown \
  --machine="MacBook Air M5 16GB"
```

The entry records the date, the `bones_api` version and commit, the machine
(CPU, cores, RAM, OS, Dart) and the DB (with the PostgreSQL server version).

## JSON decoding (client side)

`bin/json_decode_benchmark.dart` measures the other end: decoding a response
of `user/list` (a JSON list of users, each with its address and 2 roles,
encoded as `APIServer` encodes it) into entities, as a client does. It has
no `dart:io` dependency, so it also runs compiled to JavaScript and Wasm,
which is what a browser runs:

```bash
# VM:
dart run bin/json_decode_benchmark.dart [--sizes=1,20,100,1000] [--measure=2000]

# JavaScript, with the dart2js release defaults (`webdev build --release`):
dart compile js --minify bin/json_decode_benchmark.dart -o build/bench.js
node build/bench.js

# Wasm:
dart compile wasm -O2 --minify bin/json_decode_benchmark.dart -o build/bench.wasm
```

Compiled to JavaScript, `node` doesn't pass the options to `main`: it runs
the defaults. The Wasm module is run in `node` with a small loader that
calls `compile` and `instantiate` of the generated `.mjs`, then
`invokeMain(...args)`.

Each payload size is measured in layers, to attribute the cost:

| Benchmark | Measures |
|---|---|
| `dart:convert decode` | The JSON text to maps only |
| `fromMap (hand-written)` | Maps to entities by hand: the floor |
| `User$reflection.fromJson` | Maps to entities through `reflection_factory` |
| `Json.fromJsonList<User>` | Maps to entities through `Json` (entity handlers and an entity cache) |
| `Json.decode<List<User>>` | The JSON text to entities |
| `proxy: decodeJson + resolveResponse` | What a generated `APIModuleProxy` method does with a response body (without the request) |

Before measuring, it checks that every decoder gives back the users that
were encoded.

1000 users through the proxy, µs per user (Apple M5, Node 26, Dart 3.13.5):

| | 1.23.1 | 1.24.0 |
|---|--:|--:|
| JavaScript (dart2js `-O1 --minify`) | 27.4 | 11.8 |
| Wasm (dart2wasm `-O2 --minify`) | 6.5 | 3.7 |
| VM | 7.5 | 3.9 |

Compiled to JavaScript, about a third of what's left is implicit type checks
(parameters, casts): the same code compiled with `-O3`
(`--omit-implicit-checks`) decodes in 7.2 µs per user instead of 11.4. Parsing
the JSON text itself is ~5% of it (the browser's `JSON.parse`).

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
