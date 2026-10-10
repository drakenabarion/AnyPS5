#include "SceTypes.hpp"
#include "prx/libc/include/general/VabiMacros.hpp"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <thread>
#include <vector>

extern "C" {
int APS5_VABI sceAudioOutOpen(int, int, int, std::uint32_t, std::uint32_t, std::uint32_t);
int APS5_VABI sceAudioOutClose(int);
int APS5_VABI sceAudioOutOutput(int, const void*);
}

static void Require(bool value, const char* message, double a = 0, double b = 0) {
    if (value) return;
    std::fprintf(stderr, "%s (%.2f, %.2f)\n", message, a, b);
    std::abort();
}

namespace {

constexpr int user = 0x10000000;
constexpr int portTypeMain = 0;
constexpr int portTypeBgm = 1;
constexpr std::uint32_t formatS16Stereo = 1;
constexpr std::uint32_t frames = 256;
constexpr std::uint32_t frequency = 48000;
constexpr double bufferMs = 1000.0 * frames / frequency;
constexpr double targetLatencyMs = 40.0;

double NowMs() {
    return std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now().time_since_epoch()).count();
}

}  // namespace

// A port is paced by the audio it holds: after the queue reaches the target latency each output
// waits about one buffer, smoothly, rather than in whole device periods, and the wait does not hold
// up other ports.
int main() {
    const std::vector<std::int16_t> block(frames * 2, 0);
    const int main = sceAudioOutOpen(user, portTypeMain, 0, frames, frequency, formatS16Stereo);
    Require(main > 0, "main port must open");
    const int bgm = sceAudioOutOpen(user, portTypeBgm, 0, frames, frequency, formatS16Stereo);
    Require(bgm > 0, "bgm port must open");

    constexpr int count = 300;
    std::vector<double> calls;
    calls.reserve(count);
    const double start = NowMs();
    std::atomic<bool> stop{false};
    std::atomic<double> worstOtherPort{0.0};
    std::thread other([&] {
        // The second port only writes when its own queue has room, so any wait it sees comes from
        // the first port's pacing.
        while (!stop.load()) {
            const double before = NowMs();
            Require(sceAudioOutOutput(bgm, block.data()) == static_cast<int>(frames), "bgm output must accept the block");
            const double took = NowMs() - before;
            if (took > worstOtherPort.load()) worstOtherPort.store(took);
            std::this_thread::sleep_for(std::chrono::milliseconds(20));
        }
    });
    for (int i = 0; i < count; ++i) {
        const double before = NowMs();
        Require(sceAudioOutOutput(main, block.data()) == static_cast<int>(frames), "output must accept the block");
        calls.push_back(NowMs() - before);
    }
    const double elapsed = NowMs() - start;
    stop = true;
    other.join();

    const double expected = count * bufferMs - targetLatencyMs;
    std::printf("%d outputs of %.2f ms took %.1f ms (expected about %.1f)\n", count, bufferMs, elapsed, expected);
    Require(elapsed > expected * 0.9 && elapsed < expected * 1.15, "outputs must run at the real-time rate", elapsed, expected);

    std::vector<double> steady(calls.begin() + count / 3, calls.end());
    std::sort(steady.begin(), steady.end());
    const double p95 = steady[steady.size() * 95 / 100];
    std::printf("steady-state wait per output: median %.2f ms, p95 %.2f ms, max %.2f ms; other port worst %.2f ms\n", steady[steady.size() / 2], p95, steady.back(), worstOtherPort.load());
    Require(p95 < bufferMs * 2.5, "an output must wait about one buffer, not a device period", p95, bufferMs);
    // The bgm port writes slower than it plays, so its own queue never fills: any wait it sees is the
    // first port's.
    Require(worstOtherPort.load() < bufferMs, "another port must not wait behind this port's pacing", worstOtherPort.load(), bufferMs);

    Require(sceAudioOutClose(main) == 0, "main port must close");
    Require(sceAudioOutClose(bgm) == 0, "bgm port must close");
    return 0;
}
