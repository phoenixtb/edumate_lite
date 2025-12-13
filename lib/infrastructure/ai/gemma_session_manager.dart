import 'dart:async';

/// Global session manager for flutter_gemma
/// 
/// flutter_gemma only allows ONE inference session at a time.
/// This manager coordinates between VisionService and InferenceProvider.
class GemmaSessionManager {
  GemmaSessionManager._();
  static final GemmaSessionManager instance = GemmaSessionManager._();

  bool _isBusy = false;
  String? _currentUser; // For debugging: who holds the lock
  final _waitQueue = <Completer<void>>[];
  
  /// Check if model is busy
  bool get isBusy => _isBusy;
  
  /// Who currently holds the session
  String? get currentUser => _currentUser;

  /// Acquire exclusive access to the inference model
  /// Returns false if couldn't acquire within timeout
  Future<bool> acquire(String user, {Duration timeout = const Duration(seconds: 30)}) async {
    if (!_isBusy) {
      _isBusy = true;
      _currentUser = user;
      return true;
    }

    // Already busy - wait in queue
    final completer = Completer<void>();
    _waitQueue.add(completer);

    try {
      await completer.future.timeout(timeout);
      _isBusy = true;
      _currentUser = user;
      return true;
    } on TimeoutException {
      _waitQueue.remove(completer);
      return false;
    }
  }

  /// Release the session lock
  /// Call this in finally blocks to ensure cleanup
  void release(String user) {
    if (_currentUser != user) {
      // Warning: releasing lock not held by this user
      return;
    }
    
    _isBusy = false;
    _currentUser = null;

    // Don't immediately notify next waiter - give native session time to cleanup
    // This is especially important for Qualcomm devices
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_waitQueue.isNotEmpty && !_isBusy) {
        final next = _waitQueue.removeAt(0);
        if (!next.isCompleted) {
          next.complete();
        }
      }
    });
  }

  /// Force release (for error recovery)
  void forceRelease() {
    _isBusy = false;
    _currentUser = null;
    
    // Clear all waiters with error
    for (final completer in _waitQueue) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    _waitQueue.clear();
  }
}

