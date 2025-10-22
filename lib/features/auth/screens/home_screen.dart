import 'package:dognal1/core/providers/auth_provider.dart';
// --- [추가] 반려견 프로필 정보를 가져오기 위해 import 합니다. ---
import 'package:dognal1/core/providers/dog_provider.dart';
import 'package:dognal1/core/providers/analysis_provider.dart';
import 'package:dognal1/features/dog_profile/screens/edit_dog_profile_screen.dart';
import 'package:dognal1/features/dog_profile/screens/create_dog_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dognal1/features/diary/screens/diary_screen.dart';
import 'package:dognal1/features/walk/screens/walk_screen.dart';
import 'package:dognal1/features/chatbot/screens/chatbot_modal.dart';
import 'package:dognal1/features/tamagotchi/screens/tamagotchi_screen.dart';
import 'package:dognal1/features/dog_stats/screens/dog_stats_screen.dart';
import 'package:dognal1/features/analysis/analysis_screen.dart';

// --- [수정] HomeScreen을 ConsumerStatefulWidget으로 변경 ---
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // --- [추가] 네비게이션 바의 현재 인덱스 ---
  int _selectedIndex = 0;

  // --- [추가] 네비게이션 바 탭 핸들러 ---
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // --- [추가] 새로운 파스텔 색상 정의 ---
  final Color pastelBluePurple = const Color(0xFF7986CB); // Indigo 300

  @override
  Widget build(BuildContext context) {
    final dogIdAsync = ref.watch(dogIdProvider);
    // --- [삭제] user와 userEmail은 AppBar에서 더 이상 사용되지 않습니다. ---
    // final user = ref.watch(userProvider);
    // final userEmail = user?.email ?? 'User';

    // dogIdAsync.when을 Scaffold 바깥으로 이동시켜 로딩/에러/데이터 없음을 먼저 처리
    return dogIdAsync.when(
      data: (dogId) {
        // --- [수정] dogId가 없으면 프로필 생성 화면을 먼저 보여줌 ---
        if (dogId == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('반려견 프로필이 없습니다.'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateDogProfileScreen(),
                        ),
                      ).then((_) {
                        // 프로필 생성 후 dogId를 다시 불러옵니다.
                        ref.invalidate(dogIdProvider);
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pastelBluePurple, // [수정] 색상 적용
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('반려견 프로필 만들기'),
                  ),
                ],
              ),
            ),
          );
        }

        // --- [추가] dogId가 있을 경우 AppBar에 이름을 표시하기 위해 프로필을 watch ---
        final dogProfileAsync = ref.watch(dogProfileProvider(dogId));

        // --- [추가] dogId가 있을 경우 네비게이션 될 화면 목록 ---
        final List<Widget> widgetOptions = <Widget>[
          HomeScreenContent(dogId: dogId), // 홈
          DiaryScreen(dogId: dogId), // 일기
          WalkScreen(dogId: dogId), // 산책
          DogStatsScreen(dogId: dogId), // 통계
        ];

        // --- [수정] dogId가 있으면 네비게이션 바가 포함된 Scaffold를 반환 ---
        return Scaffold(
          backgroundColor: const Color(0xFFF8F7FF),
          appBar: AppBar(
            // --- [수정] title을 로고 + 반려견 이름으로 변경 ---
            title: dogProfileAsync.when(
              data: (dogProfile) => Row(
                mainAxisSize: MainAxisSize.min, // title 영역에 맞게 크기 조절
                children: [
                  // 로고 이미지 (경로와 높이 조절)
                  Image.asset(
                    'assets/images/dognal1.png', // 사용자가 요청한 로고 경로
                    height: 32, // AppBar 높이에 맞게 조절
                  ),
                  const SizedBox(width: 10),
                  // 반려견 이름
                  Text(
                    dogProfile.name,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // 로딩/에러 시 로고만 표시
              loading: () =>
                  Image.asset('assets/images/dognal1.png', height: 32),
              error: (e, s) =>
                  Image.asset('assets/images/dognal1.png', height: 32),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.pets, color: Colors.black54),
                tooltip: '반려견 프로필 보기/수정',
                onPressed: () {
                  // EditDogProfileScreen으로 dogId를 전달하며 이동합니다.
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditDogProfileScreen(dogId: dogId),
                    ),
                  );
                },
              ),
            ],
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          // --- [수정] IndexedStack을 사용하여 탭 간 상태 유지 ---
          body: IndexedStack(
            index: _selectedIndex,
            children: widgetOptions,
          ),
          // --- [추가] 하단 네비게이션 바 ---
          bottomNavigationBar: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: '홈',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.book_outlined),
                activeIcon: Icon(Icons.book),
                label: '일기',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.pets_outlined),
                activeIcon: Icon(Icons.pets),
                label: '산책',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_outlined),
                activeIcon: Icon(Icons.bar_chart),
                label: '통계',
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: pastelBluePurple, // [수정] 선택된 아이템 색상
            unselectedItemColor: Colors.grey, // 선택되지 않은 아이템 색상
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed, // 4개 이상의 탭을 고정으로
            backgroundColor: Colors.white,
            elevation: 5,
          ),
          // --- [삭제] FloatingActionButton 제거 ---
        );
      },
      loading: () =>
      const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) =>
          Scaffold(body: Center(child: Text('오류 발생: $err'))),
    );
  }
}

// --- [수정] HomeScreenContent 위젯 (레이아웃 및 버튼 스타일 변경) ---
class HomeScreenContent extends ConsumerWidget {
  final String dogId;

  const HomeScreenContent({required this.dogId, super.key});

  // --- [추가] 새로운 파스텔 색상 정의 ---
  final Color pastelBluePurple = const Color(0xFF7986CB); // Indigo 300

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // [수정] LayoutBuilder와 ConstrainedBox를 사용하여 최소 높이를 화면 높이로 설정
    // 이렇게 하면 Column이 전체 공간을 차지하고 버튼을 하단에 배치할 수 있습니다.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            // [수정] 부모(SingleChildScrollView)의 패딩값을 뺀 최소 높이 설정
            constraints: BoxConstraints(
              minHeight:
              constraints.maxHeight - 32.0, // 16.0 (top) + 16.0 (bottom)
            ),
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment.start, // [수정] spaceBetween -> start로 변경하여 위쪽에 붙임
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // --- 상단 컨텐츠 (오늘의 컨디션) ---
                Column(
                  children: [
                    Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      color: Colors.transparent,
                      child: TamagotchiScreen(dogId: dogId),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),

                // --- 하단 컨텐츠 (버튼) ---
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- [수정] "AI 분석" 버튼 ---
                    _buildSpecialActionButton(
                      context: context,
                      icon: Icons.science_outlined,
                      label: 'AI 분석 시작하기',
                      color: pastelBluePurple, // [수정] 색상 전달
                      onPressed: () {
                        // --- [수정] AnalysisScreen을 모달로 띄우도록 변경 ---
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled:
                          true, // 화면의 많은 부분을 차지할 수 있도록 설정
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20)),
                          ),
                          builder: (BuildContext context) {
                            return AnalysisScreen(dogId: dogId);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16), // [추가] 버튼 사이 간격

                    // --- [추가] "챗봇" 버튼 ---
                    _buildSpecialActionButton(
                      context: context,
                      icon: Icons.chat_bubble_outline,
                      label: '챗봇에게 물어보기',
                      color: pastelBluePurple, // [수정] 색상 전달
                      onPressed: () {
                        // 기존 FAB의 챗봇 모달 로직
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (BuildContext context) {
                            return ChatbotModal(dogId: dogId);
                          },
                        );
                      },
                    ),
                  ],
                ),
                // --- [삭제] 나머지 네비게이션 버튼들 ---
              ],
            ),
          ),
        );
      },
    );
  }

  // --- [삭제] _buildNavigationButton 함수 (더 이상 사용되지 않음) ---

  // --- [수정] 버튼 스타일을 좀 더 크고 둥글게 변경, 색상을 파라미터로 받음 ---
  Widget _buildSpecialActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color, // [추가]
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white, size: 28), // [수정] 아이콘 크기
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color, // [수정] 메인 컬러
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24), // [수정] 버튼 크기 키움
        textStyle: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold), // [수정] 폰트 크기
      ),
    );
  }
}