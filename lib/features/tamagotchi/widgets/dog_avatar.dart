import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

enum DogState { idle, happy, sad, energetic, tired }
enum InteractiveMotion { bark, attack, jump, dash }

class DogAvatar extends FlameGame with TapCallbacks {
  final double positiveScore;
  final double activeScore;

  DogAvatar({required this.positiveScore, required this.activeScore});

  late SpriteAnimationComponent _dogComponent;
  late SpriteComponent _backgroundComponent; // 하늘 (구름 스트립)
  late SpriteComponent _floorComponent;    // 바닥 (잔디)
  late DogState currentState;
  bool _isPerformingInteractiveMotion = false;
  late SpriteAnimation _originalAnimation;

  // 바닥의 높이를 정의합니다.
  static const double floorHeight = 100.0;
  // 하늘 스트립의 높이(두께)
  static const double skyStripHeight = 90.0;
  // ✨ [수정] 하늘 스트립의 Y축 위치를 20.0으로 변경하여 위로 올립니다.
  static const double skyStripYPosition = -50.0;
  // 강아지 수직 오프셋
  static const double dogVerticalOffset = 90.0;

  final Map<InteractiveMotion, ({String imagePath, int frameCount, double stepTime})> _interactiveMotions = {
    InteractiveMotion.bark: (imagePath: 'dog_bark_strip6.png', frameCount: 6, stepTime: 0.1),
    InteractiveMotion.attack: (imagePath: 'dog_attack_strip7.png', frameCount: 7, stepTime: 0.1),
    InteractiveMotion.jump: (imagePath: 'dog_jump_strip8.png', frameCount: 8, stepTime: 0.12),
    InteractiveMotion.dash: (imagePath: 'dog_dash_strip9.png', frameCount: 9, stepTime: 0.08),
  };

  @override
  Color backgroundColor() => Colors.transparent; // 배경색을 투명으로 설정

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // ✨ [추가] positiveScore 값에 따라 낮/밤 배경 이미지를 선택합니다.
    // 50 (0.5) 이상일 경우 낮(morning), 미만일 경우 밤(night)으로 설정합니다.
    final String backgroundImgPath =
    positiveScore >= 0.3 ? 'cloud_morning_normal.png' : 'cloud_night_normal.png';

    // 하늘 배경 이미지 로드 (스트립 형태로)
    final backgroundImage = await images.load(backgroundImgPath);
    _backgroundComponent = SpriteComponent.fromImage(
      backgroundImage,
      size: Vector2(size.x, skyStripHeight),
      position: Vector2(0, skyStripYPosition), // 수정된 Y 위치 적용
    );
    // _backgroundComponent.priority = -2; // <- 제거
    add(_backgroundComponent);

    // 잔디 바닥 이미지 로드 및 추가
    final floorImage = await images.load('jun_grass.png');
    _floorComponent = SpriteComponent.fromImage(
      floorImage,
      size: Vector2(size.x, floorHeight),
      position: Vector2(0, size.y - floorHeight),
    );
    // _floorComponent.priority = -1; // <- 제거
    add(_floorComponent);

    currentState = _getStateFromScores();
    _dogComponent = await _loadAnimation(currentState);
    add(_dogComponent);
    _dogComponent.position = Vector2(
      size.x / 2,
      size.y - floorHeight + dogVerticalOffset,
    );

    _originalAnimation = _dogComponent.animation!;
  }

  DogState _getStateFromScores() {
    if (positiveScore > 0.7) {
      return activeScore > 0.6 ? DogState.energetic : DogState.happy;
    } else if (positiveScore < 0.4) {
      return DogState.sad;
    } else {
      return activeScore < 0.4 ? DogState.tired : DogState.idle;
    }
  }

  Future<SpriteAnimationComponent> _loadAnimation(DogState state) async {
    String imagePath;
    int frameCount;
    double stepTime = 0.1;
    bool loop = true;

    switch (state) {
      case DogState.happy:
        imagePath = 'dog_jump_strip8.png';
        frameCount = 8;
        stepTime = 0.12;
        break;
      case DogState.sad:
        imagePath = 'dog_crouch_strip8.png';
        frameCount = 8;
        break;
      case DogState.energetic:
        imagePath = 'dog_run_strip8.png';
        frameCount = 8;
        stepTime = 0.08;
        break;
      case DogState.tired:
        imagePath = 'dog_sit_strip8.png';
        frameCount = 8;
        break;
      case DogState.idle:
      default:
        imagePath = 'dog_idle_blink_strip8.png';
        frameCount = 8;
        stepTime = 0.15;
        break;
    }

    final image = await images.load(imagePath);
    final textureSize = Vector2(image.width.toDouble() / frameCount, image.height.toDouble());
    final spriteSheet = SpriteSheet(image: image, srcSize: textureSize);
    final animation = spriteSheet.createAnimation(row: 0, stepTime: stepTime, to: frameCount, loop: loop);

    return SpriteAnimationComponent(
      animation: animation,
      size: Vector2.all(256),
      anchor: Anchor.bottomCenter,
      // priority: 0, // <- 제거
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_isPerformingInteractiveMotion) return;

    _isPerformingInteractiveMotion = true;

    final random = Random();
    final motions = _interactiveMotions.keys.toList();
    final randomMotionKey = motions[random.nextInt(motions.length)];
    final motionData = _interactiveMotions[randomMotionKey]!;

    _loadInteractiveAnimation(
      motionData.imagePath,
      motionData.frameCount,
      motionData.stepTime,
    ).then((interactiveAnimation) {
      _dogComponent.animation = interactiveAnimation;

      _dogComponent.animationTicker?.onComplete = () {
        _dogComponent.animation = _originalAnimation;
        _isPerformingInteractiveMotion = false;
        _dogComponent.animationTicker?.onComplete = null;
      };
    });
  }

  Future<SpriteAnimation> _loadInteractiveAnimation(
      String imagePath, int frameCount, double stepTime) async {
    final image = await images.load(imagePath);
    final textureSize = Vector2(image.width.toDouble() / frameCount, image.height.toDouble());
    final spriteSheet = SpriteSheet(image: image, srcSize: textureSize);
    return spriteSheet.createAnimation(
      row: 0,
      stepTime: stepTime,
      to: frameCount,
      loop: false,
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isMounted) {
      // 배경(하늘 스트립) 컴포넌트의 크기와 위치도 업데이트
      _backgroundComponent.size = Vector2(size.x, skyStripHeight);
      _backgroundComponent.position = Vector2(0, skyStripYPosition); // 수정된 Y 위치 적용

      // 바닥 컴포넌트 크기/위치 업데이트
      _floorComponent.size = Vector2(size.x, floorHeight);
      _floorComponent.position = Vector2(0, size.y - floorHeight);

      // 강아지 위치도 바닥 기준으로 업데이트
      _dogComponent.position = Vector2(
        size.x / 2,
        size.y - floorHeight + dogVerticalOffset,
      );
    }
  }
}

class DogAvatarWidget extends StatelessWidget {
  final double positiveScore;
  final double activeScore;

  const DogAvatarWidget(
      {super.key, required this.positiveScore, required this.activeScore});

  @override
  Widget build(BuildContext context) {
    return GameWidget(
      game: DogAvatar(positiveScore: positiveScore, activeScore: activeScore),
      loadingBuilder: (context) => const Center(
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(color: Color(0xFFF8F7FF)),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }
}