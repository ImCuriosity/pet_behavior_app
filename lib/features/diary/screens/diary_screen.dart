import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dognal1/data/api/rest_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✨ [수정] 앱 전체에서 사용할 단일 mockDogId 상수를 정의합니다.
const String mockDogId = 'test_dog_id_001';

// 1. Provider: 날짜를 파라미터로 받아 API를 호출하고, 결과를 캐싱합니다.
final diaryProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, DateTime>((ref, date) async {
  final restClient = ref.watch(restClientProvider);
  final accessToken = Supabase.instance.client.auth.currentSession?.accessToken;
  if (accessToken == null) {
    throw Exception('Not authenticated');
  }
  
  final dateString = DateFormat('yyyy-MM-dd').format(date);

  return await restClient.getDiaryEntry(
    dogId: mockDogId, // ✨ 통일된 mockDogId 사용
    diaryDate: dateString,
    accessToken: accessToken,
  );
});

// 2. Screen: PageView를 사용하여 책장 넘기는 효과를 구현합니다.
class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  // PageController를 사용하여 페이지 전환을 제어합니다.
  // initialPage를 1000 정도로 크게 설정하여, 거의 무한으로 왼쪽 스크롤이 가능하게 만듭니다.
  final PageController _pageController = PageController(initialPage: 1000);
  late DateTime _initialDate;

  @override
  void initState() {
    super.initState();
    _initialDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('강아지 일기 훔쳐보기'),
      ),
      body: PageView.builder(
        controller: _pageController,
        // itemcount를 매우 크게 설정하여 사실상 무한 스크롤처럼 만듭니다.
        itemCount: 2000, 
        itemBuilder: (context, index) {
          // 초기 페이지(1000)로부터의 차이를 계산하여 날짜를 결정합니다.
          final date = _initialDate.subtract(Duration(days: 1000 - index));
          return DiaryPage(date: date);
        },
      ),
    );
  }
}

// 3. Page: 각 페이지는 특정 날짜의 일기를 보여줍니다.
class DiaryPage extends ConsumerWidget {
  final DateTime date;

  const DiaryPage({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 해당 날짜의 일기 데이터를 가져옵니다.
    final diaryAsyncValue = ref.watch(diaryProvider(date));
    final formattedDate = DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(date);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(formattedDate, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Expanded(
            child: diaryAsyncValue.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('일기를 불러오지 못했어요: $error')),
              data: (diaryData) {
                final content = diaryData['content'] as String;

                return Card(
                  elevation: 4.0,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: SingleChildScrollView(
                        child: Text(
                          content,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.8),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
