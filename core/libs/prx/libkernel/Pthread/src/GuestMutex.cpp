#include "prx/libkernel/Pthread/include/GuestMutex.hpp"

#ifdef _WIN32
#include <windows.h>
#include <cstdlib>

namespace {

// Attempts before sleeping; a guest critical section usually ends within a few microseconds.
// APS5_MUTEX_SPIN=<n> overrides it for tuning.
int SpinAttempts() {
    static const int attempts = [] {
        const char* value = std::getenv("APS5_MUTEX_SPIN");
        const long parsed = value != nullptr ? std::strtol(value, nullptr, 10) : -1;
        return parsed >= 0 ? static_cast<int>(parsed) : 2000;
    }();
    return attempts;
}
constexpr std::uint32_t CONTENDED = 2;

volatile void* Word(std::atomic<std::uint32_t>& state) {
    static_assert(sizeof(std::atomic<std::uint32_t>) == sizeof(std::uint32_t), "lock word size");
    return reinterpret_cast<volatile void*>(&state);
}

}  // namespace

std::uint64_t GuestTimedMutex::steadyNanos() {
    static const std::uint64_t frequency = [] {
        LARGE_INTEGER value{};
        QueryPerformanceFrequency(&value);
        return static_cast<std::uint64_t>(value.QuadPart);
    }();
    LARGE_INTEGER counter{};
    QueryPerformanceCounter(&counter);
    const auto ticks = static_cast<std::uint64_t>(counter.QuadPart);
    return ticks / frequency * 1000000000ULL + ticks % frequency * 1000000000ULL / frequency;
}

bool GuestTimedMutex::try_lock() {
    std::uint32_t expected = 0;
    return state.compare_exchange_strong(expected, 1, std::memory_order_acquire, std::memory_order_relaxed);
}

void GuestTimedMutex::lock() {
    for (int attempt = 0, spins = SpinAttempts(); attempt < spins; ++attempt) {
        if (state.load(std::memory_order_relaxed) == 0 && try_lock()) return;
        YieldProcessor();
    }
    std::uint32_t contended = CONTENDED;
    while (state.exchange(CONTENDED, std::memory_order_acquire) != 0) WaitOnAddress(Word(state), &contended, sizeof(contended), INFINITE);
}

bool GuestTimedMutex::lockUntil(std::uint64_t deadlineNanos) {
    for (int attempt = 0, spins = SpinAttempts(); attempt < spins; ++attempt) {
        if (state.load(std::memory_order_relaxed) == 0 && try_lock()) return true;
        YieldProcessor();
    }
    std::uint32_t contended = CONTENDED;
    while (state.exchange(CONTENDED, std::memory_order_acquire) != 0) {
        const std::uint64_t now = steadyNanos();
        if (now >= deadlineNanos) return false;
        const std::uint64_t millis = (deadlineNanos - now + 999999ULL) / 1000000ULL;
        WaitOnAddress(Word(state), &contended, sizeof(contended), static_cast<DWORD>(millis > 0xFFFFFFFEULL ? 0xFFFFFFFEULL : millis));
    }
    return true;
}

void GuestTimedMutex::unlock() {
    if (state.exchange(0, std::memory_order_release) == CONTENDED) WakeByAddressSingle(const_cast<void*>(Word(state)));
}

bool GuestRecursiveTimedMutex::reenter() {
    if (owner.load(std::memory_order_relaxed) != GetCurrentThreadId()) return false;
    ++depth;
    return true;
}

void GuestRecursiveTimedMutex::adopt() {
    owner.store(GetCurrentThreadId(), std::memory_order_relaxed);
    depth = 1;
}

void GuestRecursiveTimedMutex::lock() {
    if (reenter()) return;
    inner.lock();
    adopt();
}

bool GuestRecursiveTimedMutex::try_lock() {
    if (reenter()) return true;
    if (!inner.try_lock()) return false;
    adopt();
    return true;
}

void GuestRecursiveTimedMutex::unlock() {
    if (--depth != 0) return;
    owner.store(0, std::memory_order_relaxed);
    inner.unlock();
}

#endif
