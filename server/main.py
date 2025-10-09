# main.py (테스트용 gRPC 서버 구현)
import grpc
from concurrent import futures
import time

# 자동 생성된 Protobuf 및 gRPC 스텁 파일을 import합니다.
# (생성된 파일 경로에 따라 import 경로를 조정해야 합니다.)
import pet_analysis_pb2 as pb
import pet_analysis_pb2_grpc as pb_grpc

# ----------------------------------------------------
# 1. gRPC 서비스 구현체 (Servicer)
# ----------------------------------------------------

class PetAnalysisServicer(pb_grpc.PetAnalysisServiceServicer):
    """
    PetAnalysisService 인터페이스의 gRPC 메서드를 구현합니다.
    현재는 ML 모델이 없으므로, 하드코딩된 테스트 응답을 반환합니다.
    """

    def AnalyzeSound(self, request, context):
        """소리 분석 요청을 처리합니다 (Unary Call)."""

        # 1. 인증 및 식별 정보 로깅 (실제 구현 시 여기서 JWT 검증을 수행합니다)
        print(f"[{time.strftime('%H:%M:%S')}] Received AnalyzeSound Request:")
        print(f"  Auth Token: {request.common_fields.auth_token[:10]}...")
        print(f"  Pet ID: {request.common_fields.pet_id}")

        # 2. 테스트용 응답 데이터 생성 (가짜 ML 모델 결과)
        # Flutter 클라이언트가 통신에 성공했는지 확인할 수 있도록 응답을 구성합니다.

        # ML 모델이 강아지가 "Positive" 0.8, "Active" 0.6 이라고 추론했다고 가정합니다.
        response = pb.AnalysisResult(
            positive_score=0.8,
            active_score=0.6,
            success=True,
            message=f"Sound analysis successful for Pet ID: {request.common_fields.pet_id}. Mock data returned."
        )

        # 3. 응답 반환
        return response

    # AnalyzeExpression, AnalyzeEEG, AnalyzeBodyLanguage 메서드는 현재 생략합니다.
    # 클라이언트 스트리밍 테스트는 단일 요청/응답(Unary) 테스트가 성공한 후에 진행하는 것이 효율적입니다.

# ----------------------------------------------------
# 2. gRPC 서버 실행
# ----------------------------------------------------

def serve():
    # 스레드 풀을 사용하여 서버를 실행합니다.
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))

    # 구현체를 gRPC 서버에 등록합니다.
    pb_grpc.add_PetAnalysisServiceServicer_to_server(
        PetAnalysisServicer(), server
    )

    # 포트를 바인딩하고 HTTP/2 프로토콜을 사용하여 서버를 시작합니다.
    # Google Cloud Run과 같은 환경에 배포할 경우 포트는 환경 변수(예: 8080)를 사용해야 합니다.
    port = '50051'
    server.add_insecure_port(f'[::]:{port}')
    server.start()

    print(f"gRPC Mock Server listening on port {port}")

    # 서버가 종료될 때까지 대기합니다.
    try:
        while True:
            time.sleep(86400) # 하루 동안 대기
    except KeyboardInterrupt:
        server.stop(0)

if __name__ == '__main__':
    serve()