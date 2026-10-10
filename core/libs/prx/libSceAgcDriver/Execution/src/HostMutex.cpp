#include "prx/libSceAgcDriver/Execution/include/HostMutex.hpp"

#ifdef _WIN32
#include <windows.h>

namespace AgcDriver {

static_assert(sizeof(SRWLOCK) == sizeof(void*), "SRWLOCK storage size");

void HostMutex::lock() {
    AcquireSRWLockExclusive(reinterpret_cast<PSRWLOCK>(&srw));
}

bool HostMutex::try_lock() {
    return TryAcquireSRWLockExclusive(reinterpret_cast<PSRWLOCK>(&srw)) != 0;
}

void HostMutex::unlock() {
    ReleaseSRWLockExclusive(reinterpret_cast<PSRWLOCK>(&srw));
}

}  // namespace AgcDriver
#endif
