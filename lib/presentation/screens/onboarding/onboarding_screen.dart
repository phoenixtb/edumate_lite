import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../../config/service_locator.dart';
import '../../../stores/app_store.dart';
import '../../../stores/model_download_store.dart';
import '../../../domain/services/model_download_service.dart';
import '../../../domain/services/ai_initialization_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final appStore = getIt<AppStore>();
  final downloadStore = getIt<ModelDownloadStore>();
  late final ModelDownloadService downloadService;
  late final AiInitializationService aiInitService;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🔷 [Onboarding] initState started');
    downloadService = getIt<ModelDownloadService>();
    aiInitService = getIt<AiInitializationService>();
    debugPrint('🔷 [Onboarding] Services retrieved from getIt');

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward();
    debugPrint('🔷 [Onboarding] About to call _checkModels');
    _checkModels();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkModels() async {
    debugPrint('🔷 [Onboarding] _checkModels started');
    try {
      final hasModels = await downloadService.checkModelsDownloaded();
      debugPrint('🔷 [Onboarding] hasModels = $hasModels');
      if (hasModels) {
        // Models exist, but we still need to initialize the AI providers
        debugPrint('🔷 [Onboarding] Models found, initializing providers...');
        setState(() => _isLoading = true);
        
        final initResult = await aiInitService.initializeProviders();
        
        initResult.fold(
          (failure) {
            debugPrint('❌ [Onboarding] Provider init failed: ${failure.message}');
            downloadStore.setEmbeddingError(failure.message);
            setState(() => _isLoading = false);
          },
          (_) {
            debugPrint('🔷 [Onboarding] Providers initialized, transitioning...');
            appStore.setEmbeddingModelReady(true);
            appStore.setInferenceModelReady(true);
            widget.onComplete();
          },
        );
      } else {
        debugPrint('🔷 [Onboarding] Models not ready, showing welcome view');
      }
    } catch (e) {
      debugPrint('❌ [Onboarding] _checkModels error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.secondaryContainer,
            ],
          ),
        ),
        child: SafeArea(
          child: Observer(
            builder: (_) {
              if (downloadStore.areAllModelsReady) {
                return _buildCompletionView();
              }

              if (_isLoading) {
                return _buildLoadingView();
              }

              return _buildWelcomeView();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeView() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),

          // Icon
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.school,
              size: 80,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),

          const SizedBox(height: 32),

          // Title
          Text(
            'Welcome to',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'EduMate Lite',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),

          const SizedBox(height: 16),

          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Learn smarter with your personal\nAI tutor - anytime, anywhere',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),

          const SizedBox(height: 48),

          // Features
          _FeatureItem(
            icon: Icons.lock,
            text: 'Privacy-first - all data on device',
          ),
          _FeatureItem(icon: Icons.cloud_off, text: 'Works completely offline'),
          _FeatureItem(
            icon: Icons.auto_awesome,
            text: 'Powered by on-device AI',
          ),

          const Spacer(),

          // Action button
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _loadModels,
                icon: const Icon(Icons.play_circle),
                label: const Text(
                  'Get Started',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Observer(
      builder: (_) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),

          // Progress indicator
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    strokeWidth: 8,
                    value: _calculateOverallProgress(),
                  ),
                ),
                Text(
                  '${(_calculateOverallProgress() * 100).toInt()}%',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Status text
          Text(
            _getStatusText(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Detailed status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Column(
              children: [
                _ModelLoadStatus(
                  name: 'Understanding Your Questions',
                  status: downloadStore.embeddingStatus,
                  progress: downloadStore.embeddingProgress,
                ),
                const SizedBox(height: 12),
                _ModelLoadStatus(
                  name: 'Generating Smart Answers',
                  status: downloadStore.inferenceStatus,
                  progress: downloadStore.inferenceProgress,
                ),
              ],
            ),
          ),

          if (downloadStore.embeddingError != null ||
              downloadStore.inferenceError != null) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load models',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        downloadStore.embeddingError ??
                            downloadStore.inferenceError ??
                            '',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              // Allow user to exit and use app without models
                              setState(() => _isLoading = false);
                            },
                            child: const Text('Skip for now'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: () {
                              // Clear errors and retry
                              downloadStore.setEmbeddingError(null);
                              downloadStore.setInferenceError(null);
                              downloadStore.setEmbeddingStatus(
                                ModelDownloadStatus.notStarted,
                              );
                              downloadStore.setInferenceStatus(
                                ModelDownloadStatus.notStarted,
                              );
                              setState(() => _isLoading = false);
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          const Spacer(),

          // Tip
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'This may take 30-60 seconds...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),

        // Success icon with animation
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 600),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 80,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 32),

        Text(
          'All Set!',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),

        const SizedBox(height: 16),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            'AI models are ready.\nYou can now use EduMate completely offline!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),

        const Spacer(),

        Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: () {
                appStore.setEmbeddingModelReady(true);
                appStore.setInferenceModelReady(true);
                widget.onComplete();
              },
              child: const Text(
                'Start Learning',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getStatusText() {
    if (downloadStore.embeddingStatus == ModelDownloadStatus.downloading) {
      return 'Setting up learning assistant...';
    } else if (downloadStore.inferenceStatus ==
        ModelDownloadStatus.downloading) {
      return 'Preparing answer generator...';
    } else if (downloadStore.areAllModelsReady) {
      return 'Almost ready!';
    }
    return 'Preparing...';
  }

  double _calculateOverallProgress() {
    // Calculate sequential progress (embedding first, then inference)
    if (downloadStore.embeddingStatus == ModelDownloadStatus.downloading) {
      // First half: embedding loading (0 - 0.5)
      return downloadStore.embeddingProgress * 0.5;
    } else if (downloadStore.isEmbeddingComplete &&
        downloadStore.inferenceStatus == ModelDownloadStatus.downloading) {
      // Second half: inference loading (0.5 - 1.0)
      return 0.5 + (downloadStore.inferenceProgress * 0.5);
    } else if (downloadStore.areAllModelsReady) {
      return 1.0;
    }
    return 0.0;
  }

  Future<void> _loadModels() async {
    setState(() => _isLoading = true);

    // Load embedding first
    await downloadService.loadEmbeddingModel();

    // Then load inference if embedding succeeded
    if (downloadStore.isEmbeddingComplete) {
      await downloadService.loadInferenceModel();
    }

    if (downloadStore.areAllModelsReady) {
      // Initialize AI providers after models are loaded
      final initResult = await aiInitService.initializeProviders();

      initResult.fold(
        (failure) {
          // Initialization failed
          downloadStore.setEmbeddingError(failure.message);
          setState(() => _isLoading = false);
        },
        (_) {
          // Success - mark as ready
          appStore.setEmbeddingModelReady(true);
          appStore.setInferenceModelReady(true);

          // Auto-transition after brief delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              widget.onComplete();
            }
          });
        },
      );
    } else {
      setState(() => _isLoading = false);
    }
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelLoadStatus extends StatelessWidget {
  final String name;
  final ModelDownloadStatus status;
  final double progress;

  const _ModelLoadStatus({
    required this.name,
    required this.status,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 24, height: 24, child: _buildIcon(context)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: status == ModelDownloadStatus.completed
                    ? 1.0
                    : (status == ModelDownloadStatus.downloading
                          ? progress
                          : 0.0),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIcon(BuildContext context) {
    switch (status) {
      case ModelDownloadStatus.completed:
        return Icon(
          Icons.check_circle,
          color: Theme.of(context).colorScheme.primary,
          size: 24,
        );
      case ModelDownloadStatus.downloading:
        return const CircularProgressIndicator(strokeWidth: 2);
      case ModelDownloadStatus.failed:
        return Icon(
          Icons.error,
          color: Theme.of(context).colorScheme.error,
          size: 24,
        );
      default:
        return Icon(
          Icons.pending,
          color: Theme.of(context).colorScheme.outline,
          size: 24,
        );
    }
  }
}
