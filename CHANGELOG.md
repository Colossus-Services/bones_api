## 1.0.5

- Added integration with `ReflectionFactory`.
  - Routes can be configured using a `reflection` object. 
- `APIServer`:
  - Added support to Dart VM Hot Reload.
- CLI `bones_api`:
  - Added flag `--hotreload` to serve the API with Hot Reload enabled.  
- Added `DataEntity` and `DataHandler` framework
- Added `Condition`:
  - Allow queries using a syntax similar to Dart.
- New `APIRepository`, to allow database agnostic integration.
- dart_spawner: ^1.0.5
- reflection_factory: ^1.0.4
- args: ^2.2.0 
- petitparser: ^4.2.0
- hotreloader: ^3.0.1
- logging: ^1.0.1
- collection: ^1.15.0
- lints: ^1.0.1

## 1.0.4

- CLI `bones_api`:
  - Added command `console`.
  - Command `serve`: added header `Content-Type`.
- Added `Arguments` tool.
- Added `APIRequest.fromArgs` and `APIRequest.fromArgsLine`.
- Added `APIRequest`/`APIResponse` `payloadMimeType`.

## 1.0.3

- `APIServer`:
  - Added `create` and `run` helpers.

## 1.0.2

- `APIServer`:
  - Add `isStopped` and `waitStopped()`.
  - Removed `isClosed`.
- Fix `PATCH` method.
- CLI:
  - Improved serve console logging.
- Using `dart_spawner` to spawn/run an `API`.
- dart_spawner: ^1.0.2
- Removed `yaml: ^3.1.0`

## 1.0.1

- Improve documentation.
- Fix typo.

## 1.0.0

- CLI: `bones_api` with `serve` command.
- Initial version.
