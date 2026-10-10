#include "prx/libSceAvPlayer/include/NativeSync.hpp"

#ifdef _WIN32
#include <windows.h>

namespace AvPlayer {

static_assert(sizeof(SRWLOCK) == sizeof(void*), "SRWLOCK storage size");
static_assert(sizeof(CONDITION_VARIABLE) == sizeof(void*), "CONDITION_VARIABLE storage size");

void SrwMutex::lock() {
    AcquireSRWLockExclusive(reinterpret_cast<PSRWLOCK>(&srw));
}

bool SrwMutex::try_lock() {
    return TryAcquireSRWLockExclusive(reinterpret_cast<PSRWLOCK>(&srw)) != 0;
}

void SrwMutex::unlock() {
    ReleaseSRWLockExclusive(reinterpret_cast<PSRWLOCK>(&srw));
}

void SrwCondition::notify_one() {
    WakeConditionVariable(reinterpret_cast<PCONDITION_VARIABLE>(&condition));
}

void SrwCondition::notify_all() {
    WakeAllConditionVariable(reinterpret_cast<PCONDITION_VARIABLE>(&condition));
}

void SrwCondition::wait(std::unique_lock<SrwMutex>& lock) {
    SleepConditionVariableSRW(reinterpret_cast<PCONDITION_VARIABLE>(&condition), reinterpret_cast<PSRWLOCK>(lock.mutex()->native()), INFINITE, 0);
}

}  // namespace AvPlayer

#endif
