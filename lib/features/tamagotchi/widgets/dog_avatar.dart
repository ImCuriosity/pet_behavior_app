import 'dart:math'; // Random 클래스를 사용하기 위해 import
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flame/events.dart'; // TapCallbacks를 사용하기 위해 import
import 'package:flutter/material.dart';

// 강아지의 현재 상태를 나타내는 enum
enum DogState { idle, happy, sad, energetic, tired }

// 클릭했을 때 재생할 수 있는 추가 모션들을 정의하는 enum
enum InteractiveMotion { bark, attack, jump, dash }

class DogAvatar extends FlameGame with TapCallbacks {
  final double positiveScore;
  final double activeScore;

  DogAvatar({required this.positiveScore, required this.activeScore});

  // ✨ [핵심 수정] 게임 배경색을 흰색(Colors.white)으로 설정합니다.
  @override
  Color backgroundColor() => const Color(0xFFFFFFFF); // 또는 Colors.white.toRgbColor().toColor()

  late SpriteAnimationComponent _dogComponent;
  late DogState currentState;
  bool _isPerformingInteractiveMotion = false;
  late SpriteAnimation _originalAnimation;

  // ✨ [수정] 업로드된 에셋을 기반으로 상호작용 모션 맵을 확장했습니다.
  // pubspec.yaml에 파일들이 assets/images/ 경로에 추가되었는지 확인해주세요.
  final Map<InteractiveMotion, ({String imagePath, int frameCount, double stepTime})> _interactiveMotions = {
    InteractiveMotion.bark: (imagePath: 'dog_bark_strip6.png', frameCount: 6, stepTime: 0.1),
    InteractiveMotion.attack: (imagePath: 'dog_attack_strip7.png', frameCount: 7, stepTime: 0.1),
    InteractiveMotion.jump: (imagePath: 'dog_jump_strip8.png', frameCount: 8, stepTime: 0.12),
    InteractiveMotion.dash: (imagePath: 'dog_dash_strip9.png', frameCount: 9, stepTime: 0.08),
  };

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    currentState = _getStateFromScores();
    _dogComponent = await _loadAnimation(currentState);
    add(_dogComponent);
    _dogComponent.position = size / 2;

    _originalAnimation = _dogComponent.animation!;
  }

  // ... _getStateFromScores, _loadAnimation 함수는 이전과 동일 ...
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
        imagePath = 'dog_idle_blink_strip8.png'; // 이 파일이 에셋에 있는지 확인해주세요
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
      // 현재 애니메이션을 상호작용 모션으로 교체
      _dogComponent.animation = interactiveAnimation;

      // 🔥 [핵심 수정] 에러가 발생한 부분을 아래와 같이 수정합니다.
      // SpriteAnimationComponent의 animationTicker를 통해 onComplete 콜백을 설정합니다.
      _dogComponent.animationTicker?.onComplete = () {
        // 애니메이션이 끝나면 원래 상태의 애니메이션으로 복귀
        _dogComponent.animation = _originalAnimation;
        // 플래그를 리셋하여 다시 클릭할 수 있도록 함
        _isPerformingInteractiveMotion = false;
        // 콜백을 초기화하여 반복 호출 방지
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
      loop: false, // 한 번만 재생
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isMounted) {
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
        child: CircularProgressIndicator(),
      ),
    );
  }
}