#pragma once

#include <mutex>

namespace AgcDriver {

#ifdef _WIN32
// A mutex for short, hot critical sections shared by many threads. On Windows std::mutex is a
// libwinpthread mutex whose contended path sleeps on a kernel event and wakes through the scheduler
// on every handoff; the guest's job threads resolving shader ABIs hand one lock over hundreds of times
// a frame, and those handoffs cost Quake about 40% of its main thread (65 fps where Linux runs 120).
// A slim reader/writer lock spins briefly before sleeping and hands over through keyed events.
// Not recursive; usable with std::lock_guard and std::unique_lock.
class HostMutex {
public:
    HostMutex() = default;
    HostMutex(const HostMutex&) = delete;
    HostMutex& operator=(const HostMutex&) = delete;

    void lock();
    bool try_lock();
    void unlock();

private:
    void* srw = nullptr;  // SRWLOCK storage; SRWLOCK_INIT is all zero
};
#else
using HostMutex = std::mutex;
#endif

}  // namespace AgcDriver
