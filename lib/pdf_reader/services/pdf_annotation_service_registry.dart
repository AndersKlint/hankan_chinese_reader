import 'pdf_annotation_service.dart';

class PdfAnnotationServiceRegistry {
  final Map<String, PdfAnnotationService> _services = {};

  void register(String tabId, PdfAnnotationService service) =>
      _services[tabId] = service;
  void unregister(String tabId) => _services.remove(tabId);
  PdfAnnotationService? getService(String tabId) => _services[tabId];
  bool get isBusy => _services.values.any((service) => service.isBusy);
}
