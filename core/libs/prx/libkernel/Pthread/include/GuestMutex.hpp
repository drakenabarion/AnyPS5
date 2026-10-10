#ifndef CORE_LIBS_PRX_LIBKERNEL_PTHREAD_INCLUDE_GUESTMUTEX_HPP
#define CORE_LIBS_PRX_LIBKERNEL_PTHREAD_INCLUDE_GUESTMUTEX_HPP

#include <atomic>
#include <chrono>
#include <cstdint>
#include <mutex>

#ifdef _WIN32

// The locks behind guest pthread mutexes. On Windows std::timed_mutex is a libwinpthread mutex: a
// contended lock sleeps on a kernel event at every handoff, and its timed waits measure deadlines on
// the 15.6 ms system clock. A game's job threads share their mutexes hundreds of times a frame, and
// those handoffs cost Quake's main thread close to a tenth of its time. These locks are one word:
// uncontended operations are a single atomic, a contended lock spins briefly and then sleeps on the
// word itself (WaitOnAddress), and timeouts run on the steady clock.
class GuestTimedMutex {
public:
    GuestTimedMutex() = default;
    GuestTimedMutex(const GuestTimedMutex&) = delete;
    GuestTimedMutex& operator=(const GuestTimedMutex&) = delete;

    void lock();
    bool try_lock();
    void unlock();

    template <class Rep, class Period>
    bool try_lock_for(const std::chrono::duration<Rep, Period>& duration) {
        if (try_lock()) return true;
        const auto nanos = std::chrono::duration_cast<std::chrono::nanoseconds>(duration).count();
        return lockUntil(steadyNanos() + static_cast<std::uint64_t>(nanos > 0 ? nanos : 0));
    }

    template <class Clock, class Duration>
    bool try_lock_until(const std::chrono::time_point<Clock, Duration>& deadline) {
        return try_lock_for(deadline - Clock::now());
    }

private:
    static std::uint64_t steadyNanos();
    bool lockUntil(std::uint64_t deadlineNanos);

    // 0 unlocked, 1 locked, 2 locked with sleepers.
    std::atomic<std::uint32_t> state{0};
};

class GuestRecursiveTimedMutex {
public:
    GuestRecursiveTimedMutex() = default;
    GuestRecursiveTimedMutex(const GuestRecursiveTimedMutex&) = delete;
    GuestRecursiveTimedMutex& operator=(const GuestRecursiveTimedMutex&) = delete;

    void lock();
    bool try_lock();
    void unlock();

    template <class Rep, class Period>
    bool try_lock_for(const std::chrono::duration<Rep, Period>& duration) {
        if (reenter()) return true;
        if (!inner.try_lock_for(duration)) return false;
        adopt();
        return true;
    }

    template <class Clock, class Duration>
    bool try_lock_until(const std::chrono::time_point<Clock, Duration>& deadline) {
        return try_lock_for(deadline - Clock::now());
    }

private:
    bool reenter();
    void adopt();

    GuestTimedMutex inner;
    std::atomic<std::uint32_t> owner{0};
    std::uint32_t depth = 0;
};

#else

using GuestTimedMutex = std::timed_mutex;
using GuestRecursiveTimedMutex = std::recursive_timed_mutex;

#endif

#endif
