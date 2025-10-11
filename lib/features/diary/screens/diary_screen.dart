import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dognal1/data/api/rest_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// "다시 쓰기" 기능을 위해 regenerate 파라미터를 받는 Provider로 완전히 복원합니다.
final diaryProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({DateTime date, bool regenerate, String dogId})>(
        (ref, params) async {
      final restClient = ref.watch(restClientProvider);
      final accessToken = Supabase.instance.client.auth.currentSession?.accessToken;
      if (accessToken == null) {
        throw Exception('Not authenticated');
      }

      final dateString = DateFormat('yyyy-MM-dd').format(params.date);

      // regenerate 파라미터를 포함하여 API를 호출합니다.
      return await restClient.getDiaryEntry(
        dogId: params.dogId,
        diaryDate: dateString,
        accessToken: accessToken,
        regenerate: params.regenerate,
      );
    });

class DiaryScreen extends ConsumerStatefulWidget {
  final String dogId;
  const DiaryScreen({super.key, required this.dogId});

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  // 사용자가 페이지를 넘길 수 있도록 PageController를 설정합니다.
  // initialPage를 큰 숫자로 설정하여 양방향 스크롤이 자연스럽게 느껴지도록 합니다.
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
        // 매우 많은 페이지 수를 제공하여 거의 무한 스크롤처럼 보이게 합니다.
        itemCount: 2000,
        itemBuilder: (context, index) {
          // 현재 페이지 인덱스를 기반으로 해당 날짜를 계산합니다.
          final date = _initialDate.subtract(Duration(days: 1000 - index));
          return DiaryPage(date: date, dogId: widget.dogId);
        },
      ),
    );
  }
}

// "다시 쓰기" 버튼의 상태 관리를 위해 ConsumerStatefulWidget으로 복원합니다.
class DiaryPage extends ConsumerStatefulWidget {
  final DateTime date;
  final String dogId;

  const DiaryPage({super.key, required this.date, required this.dogId});

  @override
  ConsumerState<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends ConsumerState<DiaryPage> {
  // '다시 쓰기'가 진행 중인지 여부를 추적하는 상태 변수입니다.
  bool _isRegenerating = false;

  // 주어진 날짜가 오늘인지 확인하는 헬퍼 함수입니다.
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  // '다시 쓰기' 버튼을 눌렀을 때 실행되는 함수입니다.
  Future<void> _regenerateDiary() async {
    // 사용자에게 다시 한 번 확인할 수 있는 다이얼로그를 띄웁니다.
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일기 다시 쓰기'),
        content: const Text('오늘의 최신 데이터를 반영하여 일기를 다시 작성할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('다시 쓰기')),
        ],
      ),
    );

    if (confirm != true) return; // 사용자가 '취소'를 누르면 아무것도 하지 않습니다.

    // 위젯이 화면에 마운트된 상태인지 확인하고, 로딩 상태로 변경합니다.
    if (mounted) {
      setState(() {
        _isRegenerating = true;
      });
    }

    try {
      // regenerate: true로 설정하여 API를 호출합니다.
      // .future를 사용하여 작업이 끝날 때까지 기다립니다.
      await ref.read(diaryProvider((
      date: widget.date,
      regenerate: true,
      dogId: widget.dogId,
      )).future);

      // 다시 쓰기가 완료되면, 기존 데이터를 무효화하여 화면이 새로고침되도록 합니다.
      ref.invalidate(diaryProvider(
          (date: widget.date, regenerate: false, dogId: widget.dogId)));
    } catch (e) {
      // 오류가 발생하면 사용자에게 스낵바로 알려줍니다.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('일기 다시쓰기 중 오류가 발생했어요: $e')),
        );
      }
    } finally {
      // 성공하든 실패하든, 작업이 끝나면 로딩 상태를 해제합니다.
      if (mounted) {
        setState(() {
          _isRegenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // regenerate: false로 설정하여 일반적인 일기 데이터를 가져옵니다.
    final diaryAsyncValue = ref.watch(
        diaryProvider((date: widget.date, regenerate: false, dogId: widget.dogId)));
    final formattedDate =
    DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(widget.date);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 48), // 중앙 정렬을 위한 빈 공간
              Text(formattedDate, style: Theme.of(context).textTheme.headlineSmall),
              // 오늘 날짜일 때만 '다시 쓰기' 버튼 또는 로딩 아이콘을 보여줍니다.
              if (_isToday(widget.date))
                _isRegenerating
                    ? const SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                        child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.0))))
                    : IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _regenerateDiary,
                  tooltip: '일기 다시 쓰기',
                )
              else
                const SizedBox(width: 48), // 오늘이 아니면 빈 공간
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            // '다시 쓰기' 중일 때는 별도의 로딩 화면을 보여줍니다.
            child: _isRegenerating
                ? const _RegeneratingView()
                : diaryAsyncValue.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) =>
                  Center(child: Text('일기를 불러오지 못했어요: $error', textAlign: TextAlign.center,)),
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
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(height: 1.8),
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

// '다시 쓰기' 중에 보여줄 전용 로딩 위젯입니다.
class _RegeneratingView extends StatelessWidget {
  const _RegeneratingView();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🐾', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 20),
              Text(
                '멍멍! 일기를 다시 쓰고 있어요...',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}