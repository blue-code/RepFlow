import AVFoundation
import Foundation

/// 카운트를 소리로 읽어준다.
///
/// 장식이 아니다. 푸시업 자세에서는 화면을 볼 수 없고, 근접센서 모드는 아예 화면이 꺼진다.
/// 소리가 이 앱의 실질적인 출력 채널이다.
@MainActor
final class SpeechCounter {

    /// 목표까지 이만큼 남으면 예고한다.
    private let warnAt = 3

    private let synthesizer = AVSpeechSynthesizer()
    private var voice: AVSpeechSynthesisVoice?

    var isEnabled = true

    init() {
        // 기기 언어를 따른다. 한국어가 없으면 시스템이 알아서 대체 음성을 쓴다.
        let code = Locale.preferredLanguages.first ?? "ko-KR"
        voice = AVSpeechSynthesisVoice(language: code) ?? AVSpeechSynthesisVoice(language: "ko-KR")
    }

    /// 다른 앱의 음악을 끊지 않고 얹는다 — 운동 중에 음악을 듣는 사람이 대부분이다.
    func activateAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(
            .playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers]
        )
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func deactivateAudioSession() {
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// rep 하나. 목표가 있으면 남은 개수를 예고한다.
    func announce(count: Int, target: Int?, isAMRAP: Bool) {
        guard isEnabled else { return }

        if let target, !isAMRAP {
            let remaining = target - count
            if remaining == warnAt {
                speak("\(count). \(warnAt)개 남았습니다")
                return
            }
            if remaining == 0 {
                speak("\(count). 목표 달성")
                return
            }
        }
        speak("\(count)")
    }

    func announceRest(seconds: Int) {
        guard isEnabled else { return }
        speak("휴식 \(seconds)초")
    }

    /// 휴식 종료 직전 카운트다운. 화면을 안 보고 있어도 준비할 수 있어야 한다.
    func announceRestCountdown(_ remaining: Int) {
        guard isEnabled, (1...5).contains(remaining) else { return }
        speak("\(remaining)")
    }

    func announceSetComplete(setIndex: Int, total: Int) {
        guard isEnabled else { return }
        speak(setIndex + 1 >= total ? "마지막 세트 완료" : "\(setIndex + 1)세트 완료")
    }

    func announceSessionComplete(totalReps: Int) {
        guard isEnabled else { return }
        speak("세션 완료. 총 \(totalReps)개")
    }

    private func speak(_ text: String) {
        // 카운트는 밀리면 의미가 없다 — 이전 발화를 끊고 지금 숫자를 말한다.
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.08
        synthesizer.speak(utterance)
    }
}
