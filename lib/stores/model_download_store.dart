import 'package:mobx/mobx.dart';

part 'model_download_store.g.dart';

class ModelDownloadStore = ModelDownloadStoreBase with _$ModelDownloadStore;

enum ModelDownloadStatus {
  notStarted,
  checkingStorage,
  downloading,
  paused,
  failed,
  completed,
  initializing,
}

abstract class ModelDownloadStoreBase with Store {
  @observable
  ModelDownloadStatus embeddingStatus = ModelDownloadStatus.notStarted;

  @observable
  ModelDownloadStatus inferenceStatus = ModelDownloadStatus.notStarted;

  @observable
  double embeddingProgress = 0.0;

  @observable
  double inferenceProgress = 0.0;

  @observable
  String? embeddingError;

  @observable
  String? inferenceError;

  @observable
  int? embeddingBytesDownloaded;

  @observable
  int? embeddingTotalBytes;

  @observable
  int? inferenceBytesDownloaded;

  @observable
  int? inferenceTotalBytes;

  // Phi-4 (optional download)
  @observable
  ModelDownloadStatus phi4Status = ModelDownloadStatus.notStarted;

  @observable
  double phi4Progress = 0.0;

  @observable
  String? phi4Error;

  @observable
  int? phi4BytesDownloaded;

  @observable
  int? phi4TotalBytes;

  @action
  void setEmbeddingStatus(ModelDownloadStatus status) {
    embeddingStatus = status;
  }

  @action
  void setInferenceStatus(ModelDownloadStatus status) {
    inferenceStatus = status;
  }

  @action
  void setEmbeddingProgress(double progress) {
    embeddingProgress = progress;
  }

  @action
  void setInferenceProgress(double progress) {
    inferenceProgress = progress;
  }

  @action
  void setEmbeddingError(String? error) {
    embeddingError = error;
  }

  @action
  void setInferenceError(String? error) {
    inferenceError = error;
  }

  @action
  void updateEmbeddingBytes(int downloaded, int total) {
    embeddingBytesDownloaded = downloaded;
    embeddingTotalBytes = total;
  }

  @action
  void updateInferenceBytes(int downloaded, int total) {
    inferenceBytesDownloaded = downloaded;
    inferenceTotalBytes = total;
  }

  @action
  void setPhi4Status(ModelDownloadStatus status) {
    phi4Status = status;
  }

  @action
  void setPhi4Progress(double progress) {
    phi4Progress = progress;
  }

  @action
  void setPhi4Error(String? error) {
    phi4Error = error;
  }

  @action
  void updatePhi4Bytes(int downloaded, int total) {
    phi4BytesDownloaded = downloaded;
    phi4TotalBytes = total;
  }

  @computed
  bool get isEmbeddingComplete =>
      embeddingStatus == ModelDownloadStatus.completed;

  @computed
  bool get isInferenceComplete =>
      inferenceStatus == ModelDownloadStatus.completed;

  @computed
  bool get areAllModelsReady => isEmbeddingComplete && isInferenceComplete;

  @computed
  String get embeddingProgressText {
    if (embeddingBytesDownloaded != null && embeddingTotalBytes != null) {
      final mb = embeddingBytesDownloaded! / (1024 * 1024);
      final totalMb = embeddingTotalBytes! / (1024 * 1024);
      return '${mb.toStringAsFixed(1)}MB / ${totalMb.toStringAsFixed(1)}MB';
    }
    return '${(embeddingProgress * 100).toInt()}%';
  }

  @computed
  String get inferenceProgressText {
    if (inferenceBytesDownloaded != null && inferenceTotalBytes != null) {
      final mb = inferenceBytesDownloaded! / (1024 * 1024);
      final totalMb = inferenceTotalBytes! / (1024 * 1024);
      return '${mb.toStringAsFixed(1)}MB / ${totalMb.toStringAsFixed(1)}MB';
    }
    return '${(inferenceProgress * 100).toInt()}%';
  }

  @computed
  bool get isPhi4Complete => phi4Status == ModelDownloadStatus.completed;

  @computed
  bool get isPhi4Downloading => phi4Status == ModelDownloadStatus.downloading;

  @computed
  String get phi4ProgressText {
    if (phi4BytesDownloaded != null && phi4TotalBytes != null) {
      final mb = phi4BytesDownloaded! / (1024 * 1024);
      final totalMb = phi4TotalBytes! / (1024 * 1024);
      return '${mb.toStringAsFixed(1)}MB / ${totalMb.toStringAsFixed(1)}MB';
    }
    return '${(phi4Progress * 100).toInt()}%';
  }
}

