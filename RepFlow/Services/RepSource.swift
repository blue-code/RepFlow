import Foundation

/// 자동 카운트 소스. 세는 방법만 다르고, 결과는 전부 `ProgramSessionRunner.addRep()` 으로 들어간다.
///
/// 탭·크라운은 소스가 아니라 사용자 입력이라 여기 없다 — 뷰가 직접 `addRep()` 을 부른다.
@MainActor
protocol RepSource: AnyObject {
    /// 1회 감지. 메인 액터에서 호출된다.
    var onRep: (() -> Void)? { get set }
    /// 신호 품질 변화 안내(카메라: 관절이 안 보임 등). nil이면 정상.
    var onStatus: ((String?) -> Void)? { get set }

    func start()
    func stop()
}

/// 사용자가 고르는 카운트 방식.
enum CountingMode: String, CaseIterable, Identifiable {
    /// 화면 탭 / 크라운. 항상 된다.
    case manual
    /// 폰을 바닥에 세워 정측면에서 촬영 — 폼 점수까지 나온다.
    case camera
    /// 폰을 가슴 아래 바닥에 눕힌다. 거치도 조명도 필요 없다.
    case proximity

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .manual:    return "탭"
        case .camera:    return "카메라"
        case .proximity: return "근접센서"
        }
    }

    var symbol: String {
        switch self {
        case .manual:    return "hand.tap"
        case .camera:    return "camera"
        case .proximity: return "iphone.gen3.radiowaves.left.and.right"
        }
    }

    var hint: String {
        switch self {
        case .manual:
            return "화면 어디를 눌러도 1개."
        case .camera:
            return "폰을 바닥에 세워 정측면 1.5~2m. 전신이 들어와야 합니다."
        case .proximity:
            return "폰을 가슴 아래 바닥에 화면이 위로 오게 둡니다. 가슴이 닿을 만큼 내려가면 1개."
        }
    }
}
