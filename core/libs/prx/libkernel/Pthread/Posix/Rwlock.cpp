#include <cstdint>
#include <cstddef>
#include "SceTypes.hpp"
#include "prx/libc/include/General.hpp"
#include "../include/Pthread.hpp"
#include "../include/Rwlock.hpp"
#include "Common.hpp"
#include <atomic>
#include <chrono>
#include <cstdlib>
#include "prx/libkernel/Time/include/Time.hpp"
#include <stdexcept>
#include <string>

namespace {

constexpr int GUEST_REALTIME_CLOCK = 0;

int toPosix(int result) {
    if (result == 0)
        return 0;
    const auto error = static_cast<std::uint32_t>(result);
    if ((error & 0xffff0000u) != 0x80020000u)
        throw std::runtime_error("Unexpected SCE rwlock error");
    return static_cast<int>(error & 0xffffu);
}

void initializeStatic(PthreadRwlock* rwlock, const char* funcName) {
    if (!rwlock) throw std::runtime_error(std::string(funcName) + ": null rwlock");
    std::atomic_ref<PthreadRwlock> slot(*rwlock);
    PthreadRwlock current = slot.load(std::memory_order_acquire);
    if (current != nullptr) return;
    auto* created = new PthreadRwlockPrivate();
    if (!slot.compare_exchange_strong(current, created, std::memory_order_acq_rel, std::memory_order_acquire))
        delete created;
}

}

extern "C" {

int APS5_VABI pthread_rwlock_destroy_nid_postfix(PthreadRwlock* rwlock) {
    if (!rwlock) throw std::runtime_error("pthread_rwlock_destroy: null rwlock");
    if (*rwlock == nullptr) return 0;
    return toPosix(scePthreadRwlockDestroy(rwlock));
}

int APS5_VABI pthread_rwlock_init_nid_postfix(PthreadRwlock* rwlock, const PthreadRwlockattr* attr) {
    return toPosix(scePthreadRwlockInit(rwlock, attr, nullptr));
}

int APS5_VABI pthread_rwlock_rdlock_nid_postfix(PthreadRwlock* rwlock) {
    initializeStatic(rwlock, __func__);
    static const bool timeline = std::getenv("APS5_TRACE_TIMELINE") != nullptr;
    if (!timeline) return toPosix(scePthreadRwlockRdlock(rwlock));
    const auto start = std::chrono::steady_clock::now();
    const int result = toPosix(scePthreadRwlockRdlock(rwlock));
    KernelTimelineEvent_nid_postfix("rdlock", __builtin_return_address(0), static_cast<std::uint64_t>(std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::steady_clock::now() - start).count()));
    return result;
}

int APS5_VABI pthread_rwlock_timedrdlock_nid_postfix(PthreadRwlock* rwlock, const KernelTimespec* abstime) {
    if (!abstime) throw std::runtime_error("pthread_rwlock_timedrdlock: null abstime");
    initializeStatic(rwlock, __func__);
    if (scePthreadRwlockTryrdlock(rwlock) == 0) return 0;
    KernelUseconds usec = 0;
    if (!PosixThread::RelativeMicroseconds(GUEST_REALTIME_CLOCK, abstime, &usec)) return PosixThread::GUEST_EINVAL;
    return toPosix(scePthreadRwlockTimedrdlock(rwlock, usec));
}

int APS5_VABI pthread_rwlock_timedwrlock_nid_postfix(PthreadRwlock* rwlock, const KernelTimespec* abstime) {
    if (!abstime) throw std::runtime_error("pthread_rwlock_timedwrlock: null abstime");
    initializeStatic(rwlock, __func__);
    if (scePthreadRwlockTrywrlock(rwlock) == 0) return 0;
    KernelUseconds usec = 0;
    if (!PosixThread::RelativeMicroseconds(GUEST_REALTIME_CLOCK, abstime, &usec)) return PosixThread::GUEST_EINVAL;
    return toPosix(scePthreadRwlockTimedwrlock(rwlock, usec));
}

int APS5_VABI pthread_rwlock_tryrdlock_nid_postfix(PthreadRwlock* rwlock) {
    initializeStatic(rwlock, __func__);
    return toPosix(scePthreadRwlockTryrdlock(rwlock));
}

int APS5_VABI pthread_rwlock_trywrlock_nid_postfix(PthreadRwlock* rwlock) {
    initializeStatic(rwlock, __func__);
    return toPosix(scePthreadRwlockTrywrlock(rwlock));
}

int APS5_VABI pthread_rwlock_unlock_nid_postfix(PthreadRwlock* rwlock) {
    initializeStatic(rwlock, __func__);
    return toPosix(scePthreadRwlockUnlock(rwlock));
}

int APS5_VABI pthread_rwlock_wrlock_nid_postfix(PthreadRwlock* rwlock) {
    initializeStatic(rwlock, __func__);
    static const bool timeline = std::getenv("APS5_TRACE_TIMELINE") != nullptr;
    if (!timeline) return toPosix(scePthreadRwlockWrlock(rwlock));
    const auto start = std::chrono::steady_clock::now();
    const int result = toPosix(scePthreadRwlockWrlock(rwlock));
    KernelTimelineEvent_nid_postfix("wrlock", __builtin_return_address(0), static_cast<std::uint64_t>(std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::steady_clock::now() - start).count()));
    return result;
}

}
