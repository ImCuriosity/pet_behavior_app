import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // ⭐️ [추가] MarkdownBody를 사용하기 위해 import
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

      // DB 조회 시 날짜 문자열 생성: 시간 요소를 제거하여 순수한 날짜(00:00:00) 객체를 만듭니다.
      final dateOnly = DateTime(params.date.year, params.date.month, params.date.day);
      final dateString = DateFormat('yyyy-MM-dd').format(dateOnly);

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
  final PageController _pageController = PageController(initialPage: 1000);
  late DateTime _initialDate;

  // 페이지 인덱스를 기반으로 현재 날짜를 계산하는 함수
  DateTime _getDateFromIndex(int index) {
    return _initialDate.subtract(Duration(days: 1000 - index));
  }

  // 페이지 컨트롤러를 사용하여 이전 날짜로 이동 (인덱스 감소)
  void _goToPreviousDay() {
    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  // 페이지 컨트롤러를 사용하여 다음 날짜로 이동 (인덱스 증가)
  void _goToNextDay() {
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  void initState() {
    super.initState();
    _initialDate = DateTime.now();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('강아지 일기 훔쳐보기'),
        backgroundColor: Colors.brown.shade200, // 책 테마에 맞는 AppBar 색상
      ),
      // 배경에 은은한 종이 질감 색상을 추가
      backgroundColor: Colors.brown.shade50,
      body: PageView.builder(
        controller: _pageController,
        // 매우 많은 페이지 수를 제공하여 거의 무한 스크롤처럼 보이게 합니다.
        itemCount: 2000,
        itemBuilder: (context, index) {
          final date = _getDateFromIndex(index);
          return DiaryPage(
            date: date,
            dogId: widget.dogId,
            onGoToPreviousDay: _goToPreviousDay,
            onGoToNextDay: _goToNextDay,
            isCurrentDay: index == 1000, // 현재 페이지가 오늘인지 여부
          );
        },
      ),
    );
  }
}

// "다시 쓰기" 버튼의 상태 관리를 위해 ConsumerStatefulWidget으로 복원합니다.
class DiaryPage extends ConsumerStatefulWidget {
  final DateTime date;
  final String dogId;
  final VoidCallback onGoToPreviousDay;
  final VoidCallback onGoToNextDay;
  final bool isCurrentDay; // 현재 페이지가 오늘 날짜인지 판단

  const DiaryPage({
    super.key,
    required this.date,
    required this.dogId,
    required this.onGoToPreviousDay,
    required this.onGoToNextDay,
    required this.isCurrentDay,
  });

  @override
  ConsumerState<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends ConsumerState<DiaryPage> {
  // '다시 쓰기'가 진행 중인지 여부를 추적하는 상태 변수입니다.
  bool _isRegenerating = false;

  // 주어진 날짜가 오늘인지 확인하는 헬퍼 함수입니다.
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    // now와 date의 시간 정보를 제거하고 순수한 날짜(00:00:00)만 가진 객체를 생성합니다.
    final todayDate = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);

    // 시간 정보가 제거된 두 날짜 객체를 비교합니다.
    return targetDate.isAtSameMomentAs(todayDate);
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

  // ⭐️ [핵심 수정] 책 페이지 상단의 날짜와 페이징 버튼을 표시하는 위젯
  Widget _buildPageHeader(BuildContext context) {
    final formattedDate = DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(widget.date);

    // 현재 페이지가 '오늘'인지 확인
    final isCurrentPageToday = _isToday(widget.date);

    // 다음 페이지가 '오늘'을 초과하는 '미래' 날짜인지 확인합니다.
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final nextPageOnly = DateTime(widget.date.year, widget.date.month, widget.date.day).add(const Duration(days: 1));
    final isNextPageFuture = nextPageOnly.isAfter(todayOnly);

    // 다음 버튼 비활성화 여부는 현재 페이지가 '오늘'인지에 따라 결정됩니다.
    final disableNextButton = isCurrentPageToday;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 이전 페이지 버튼
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: widget.onGoToPreviousDay,
          tooltip: '이전 날짜',
        ),

        // 날짜 표시
        Expanded(
          child: Text(
            formattedDate,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.brown.shade800,
              fontWeight: FontWeight.bold,
              // 오늘 날짜라면 강조
              fontStyle: isCurrentPageToday ? FontStyle.italic : FontStyle.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // 오늘 날짜일 때만 '다시 쓰기' 버튼
        if (isCurrentPageToday)
          _isRegenerating
              ? SizedBox(
              width: 48,
              height: 48,
              child: Center(
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.brown.shade700, strokeWidth: 2.0))))
              : IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _regenerateDiary,
            tooltip: '일기 다시 쓰기',
          )
        else
        // 과거 날짜일 때: '다음 페이지' 버튼 표시
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 20),
            // 다음 페이지가 '오늘'을 초과하는 '미래'라면 비활성화
            onPressed: isNextPageFuture ? null : widget.onGoToNextDay,
            color: isNextPageFuture ? Colors.grey : Colors.black,
            tooltip: '다음 날짜',
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // regenerate: false로 설정하여 일반적인 일기 데이터를 가져옵니다.
    final diaryAsyncValue = ref.watch(
        diaryProvider((date: widget.date, regenerate: false, dogId: widget.dogId)));

    // ⭐️ [핵심 수정] 책 페이지처럼 보이도록 Padding을 제거하고 Container로 감쌉니다.
    return Center(
      child: Container(
        // 페이지 간 여백을 위한 Container의 외부 Padding
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. 책의 질감을 표현하는 기본 배경 (Card 대신 Container 사용)
            Container(
              decoration: BoxDecoration(
                color: Colors.white, // 종이 색상
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 5),
                  ),
                ],
                // 책 페이지처럼 왼쪽 중앙에 약간의 세로줄 음영 추가
                border: Border.all(color: Colors.brown.shade100, width: 1),
              ),
            ),

            // 2. 일기 내용
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // 날짜 및 페이징 버튼
                  _buildPageHeader(context),
                  const SizedBox(height: 16),

                  Expanded(
                    // '다시 쓰기' 중일 때는 별도의 로딩 화면을 보여줍니다.
                    child: _isRegenerating
                        ? const _RegeneratingView()
                        : diaryAsyncValue.when(
                      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFA0522D))),
                      error: (error, stack) =>
                          Center(child: Text('일기를 불러오지 못했어요: $error', textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700))),
                      data: (diaryData) {
                        final content = diaryData['content'] as String;

                        // ⭐️ [핵심 수정] Text 위젯 대신 MarkdownBody 위젯을 사용합니다.
                        return SingleChildScrollView(
                          child: MarkdownBody(
                            data: content,
                            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                              // 본문 스타일을 Text 위젯과 유사하게 유지하되 MarkdownBody를 통해 렌더링
                              p: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                height: 1.8,
                                color: Colors.brown.shade900,
                              ),
                              // 폰트 크기 변경으로 인한 줄 높이 문제 해결
                              listIndent: 30, // 목록 들여쓰기 조정
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// '다시 쓰기' 중에 보여줄 전용 로딩 위젯입니다.
class _RegeneratingView extends StatelessWidget {
  const _RegeneratingView();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🐾', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 20),
            Text(
              '멍멍! 일기를 다시 쓰고 있어요...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.brown.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.brown.shade700),
          ],
        ),
      ),
    );
  }
}