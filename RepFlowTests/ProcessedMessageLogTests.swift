import Foundation
import Testing
@testable import RepFlow

/// 종료 리포트는 빠른 경로와 보장 경로로 이중 송신되므로 같은 내용이 두 번 도착한다.
/// 중복 제거가 깨지면 운동 한 번이 기록 두 줄이 된다.
@Suite("메시지 중복 제거", .serialized)
struct ProcessedMessageLogTests {

    init() { ProcessedMessageLog.reset() }

    @Test("같은 ID가 두 번 오면 두 번째는 중복이다")
    func detectsDuplicate() {
        #expect(ProcessedMessageLog.isDuplicate("a") == false)
        ProcessedMessageLog.remember("a")
        #expect(ProcessedMessageLog.isDuplicate("a") == true)
        #expect(ProcessedMessageLog.isDuplicate("b") == false)
        ProcessedMessageLog.reset()
    }

    @Test("ID 없는 실시간 메시지는 중복으로 보지 않는다")
    func ignoresNilId() {
        ProcessedMessageLog.remember(nil)
        #expect(ProcessedMessageLog.isDuplicate(nil) == false)
        #expect(ProcessedMessageLog.isDuplicate(nil) == false)
        ProcessedMessageLog.reset()
    }

    @Test("기록은 무한히 쌓이지 않고 오래된 것부터 버린다")
    func boundsHistory() {
        for i in 0..<80 { ProcessedMessageLog.remember("id-\(i)") }

        #expect(ProcessedMessageLog.isDuplicate("id-79") == true, "최근 것은 남아 있어야 한다")
        #expect(ProcessedMessageLog.isDuplicate("id-0") == false, "오래된 것은 밀려나야 한다")
        ProcessedMessageLog.reset()
    }
}
