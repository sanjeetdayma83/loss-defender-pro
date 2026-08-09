abstract class BarcodeScanner {
  Future<String?> scanOnce();
  Future<void> dispose();
}

/// Camera / ML kit implementation hooks here
class CameraBarcodeScanner implements BarcodeScanner {
  @override
  Future<String?> scanOnce() async => null; // wire mobile_scanner

  @override
  Future<void> dispose() async {}
}

/// USB HID keyboard-wedge: listen to text input focus
class HidBarcodeScanner implements BarcodeScanner {
  @override
  Future<String?> scanOnce() async => null;

  @override
  Future<void> dispose() async {}
}