import 'bones_api_data.dart';

/// A data repository API.
abstract class APIRepository<O> {
  final DataRepository<O> dataRepository;

  APIRepository(this.dataRepository) {
    dataRepository.ensureInitialized();
  }

  void configure();

  bool _configured = false;

  void ensureConfigured() {
    if (_configured) return;
    _configured = true;
    configure();
  }
}
