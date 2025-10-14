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
  late SpriteComponent _backgroundComponent; // ✨ [추가] 배경 컴포넌트
  late DogState currentState;
  bool _isPerformingInteractiveMotion = false;
  late SpriteAnimation _originalAnimation;

  final Map<InteractiveMotion, ({String imagePath, int frameCount, double stepTime})> _interactiveMotions = {
    InteractiveMotion.bark: (imagePath: 'dog_bark_strip6.png', frameCount: 6, stepTime: 0.1),
    InteractiveMotion.attack: (imagePath: 'dog_attack_strip7.png', frameCount: 7, stepTime: 0.1),
    InteractiveMotion.jump: (imagePath: 'dog_jump_strip8.png', frameCount: 8, stepTime: 0.12),
    InteractiveMotion.dash: (imagePath: 'dog_dash_strip9.png', frameCount: 9, stepTime: 0.08),
  };

  @override
  Color backgroundColor() => Colors.transparent; // ✨ [수정] 배경색을 투명으로 설정하여 이미지가 보이도록 함

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // ✨ [추가] 배경 이미지 로드 및 추가
    final backgroundImage = await images.load('cloud_morning_normal.png');
    _backgroundComponent = SpriteComponent.fromImage(
      backgroundImage,
      size: size, // 게임 화면 전체 크기에 맞춤
      position: Vector2.zero(),
    );
    _backgroundComponent.priority = -1; // 강아지 애니메이션보다 뒤에 렌더링되도록 우선순위 설정
    add(_backgroundComponent);

    currentState = _getStateFromScores();
    _dogComponent = await _loadAnimation(currentState);
    add(_dogComponent);
    _dogComponent.position = size / 2;
    _dogComponent.priority = 0; // 강아지는 배경보다 위에 렌더링되도록 설정

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

    return SpriteAnimationComponent(animation: animation, size: Vector2.all(256), anchor: Anchor.center);
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
      // ✨ [수정] 배경 컴포넌트의 크기와 위치도 업데이트
      _backgroundComponent.size = size;
      _dogComponent.position = size / 2;
    }
  }
}

// DogAvatarWidget은 수정할 필요 없습니다.
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
        // ✨ [수정] 로딩 중 배경색을 설정하여 흰색 깜빡임을 방지
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(color: Color(0xFFF8F7FF)), // 홈 화면 배경색과 동일하게
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }
}