#ifndef CORE_LIBS_PRX_LIBSCEAUDIOOUT_SRC_SDLAUDIO_HPP
#define CORE_LIBS_PRX_LIBSCEAUDIOOUT_SRC_SDLAUDIO_HPP

#include <mutex>

#include "SDL.h"

inline std::mutex& SdlAudioMutex() {
    static auto* mutex = new std::mutex();
    return *mutex;
}

inline bool SdlAudioEnsureInit() {
    return SDL_WasInit(SDL_INIT_AUDIO) != 0 || SDL_InitSubSystem(SDL_INIT_AUDIO) == 0;
}

#endif
