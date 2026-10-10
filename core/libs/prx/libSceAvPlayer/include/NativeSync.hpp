#ifndef CORE_LIBS_PRX_LIBSCEAVPLAYER_INCLUDE_NATIVESYNC_HPP
#define CORE_LIBS_PRX_LIBSCEAVPLAYER_INCLUDE_NATIVESYNC_HPP

#include <condition_variable>
#include <mutex>

namespace AvPlayer {

#ifdef _WIN32

// The player's state lock and its condition variable. On the MinGW posix toolchain std::mutex and
// std::condition_variable are libwinpthread objects: each contended handoff sleeps on a kernel event.
// The game polls the player from its main thread every frame while the demuxer and decoder threads
// take the same lock for microseconds at a time, and those handoffs cost Quake's main thread about a
// tenth of its time. Windows' slim reader/writer lock and native condition variable spin briefly and
// hand over through keyed events.
class SrwMutex {
public:
    SrwMutex() = default;
    SrwMutex(const SrwMutex&) = delete;
    SrwMutex& operator=(const SrwMutex&) = delete;

    void lock();
    bool try_lock();
    void unlock();
    void* native() { return &srw; }

private:
    void* srw = nullptr;  // SRWLOCK storage; SRWLOCK_INIT is all zero
};

class SrwCondition {
public:
    SrwCondition() = default;
    SrwCondition(const SrwCondition&) = delete;
    SrwCondition& operator=(const SrwCondition&) = delete;

    void notify_one();
    void notify_all();
    void wait(std::unique_lock<SrwMutex>& lock);

    template <class Predicate>
    void wait(std::unique_lock<SrwMutex>& lock, Predicate predicate) {
        while (!predicate()) wait(lock);
    }

private:
    void* condition = nullptr;  // CONDITION_VARIABLE storage; CONDITION_VARIABLE_INIT is all zero
};

using StateMutex = SrwMutex;
using StateCondition = SrwCondition;

#else

using StateMutex = std::mutex;
using StateCondition = std::condition_variable;

#endif

}  // namespace AvPlayer

#endif
