#ifndef RELINKER_GUESTIMAGE_HPP
#define RELINKER_GUESTIMAGE_HPP

#include <codegen/CodegenTypes.hpp>
#include <domain/Types.hpp>
#include <relinker/domain/ISyscallScanner.hpp>
#include <filesystem>
#include <set>
#include <string>

namespace Relinker {

inline constexpr char GuestSymbolSuffix[] = "#guest";
inline constexpr char GuestModuleSuffix[] = ".guest.prx";
inline constexpr std::uint16_t AbsoluteSection = 0xfff1;

inline bool IsHostRuntimeSymbol(const std::string& name) {
    static const std::set<std::string> nids{
    "s62MgBhosjU", "GslDM6l8E7U", "zs817D8+hPA", "MmTshn7gIgU", "nqD9bBu-W6U", "oQpl5qCT014", "sETNbyWsEHs", "5-3wdp3FVtc",
    "gpc4YXZffkQ", "p3BVovMPEE4", "HPlmfRhMWwo", "wpNJwmDDtxw", "f1zwJ3jAI2k", "xUsJSLsdv9I", "Xr4pio56GGQ", "BWAtsvaXToA",
    "Q1BL70XVV0o", "qYhnoevd9bI", "cfAXurvfl5o", "tsvEmnenz48", "3cUUypQzMiI", "BxPeH9TTcs4", "RY8mQlhg7mI", "MQFPAqQPt1s",
    "lX+4FNUklF0", "nOIEswYD4Ig", "Y6Sl4Xw7gfA", "3rJJb81CDM4", "uCRed7SvX5E", "2emaaluWzUw", "3GPpjQdAMTw", "9rAeANT2tyE",
    "PsrRUg671K0", "zr094EQ39Ww", "ZL9FV4mJXxo", "qKQiNX91IGo", "vkuuLfhnSZI", "cmBRQsLPqwA", "vyQXAltCcuI", "XwLA5cTHjt4",
    "LYo3GhIlB38", "-hn1tcVHq5Q", "W6SiVSiCDtI", "Vla-Z+eXlxo", "OJjm-QOIHlI", "mfHdJTIvhuo", "k04jLXu3+Ic", "fEoW6BJsPt4",
    "iF1iQHzxBJU", "qWESlyXMI3E", "gigoVHZvVPE", "p6lrRW8-MLY",
};
    return nids.contains(name);
}

struct GuestSymbol {
    std::string Name;
    std::uint8_t Info;
    std::uint8_t Visibility;
    std::uint16_t Section;
    std::uint64_t Value;
    std::uint64_t Size;
    std::string Library;
};

struct GuestImage {
    std::filesystem::path SourcePath;
    std::string OutputName;
    std::string Soname;
    std::vector<std::uint8_t> Bytes;
    std::vector<Codegen::TrampolineSite> Trampolines;
    std::vector<Domain::ProgramHeader> Headers;
    std::vector<GuestSymbol> Symbols;
    std::vector<std::string> Dependencies;
    Domain::SysVDynamicSection Dynamic;
    std::vector<std::uint64_t> InitArray;
    std::vector<std::uint64_t> FiniArray;
    std::uint64_t Init = 0;
    std::uint64_t Fini = 0;
    std::uint64_t Got = 0;
    bool UsePlatformTlsResolver = true;
};

class GuestImageReader {
public:
    GuestImage Read(const std::filesystem::path& path, std::vector<std::uint8_t> bytes) const;
};

struct GuestArtifact {
    std::filesystem::path Path;
    std::vector<std::uint8_t> Bytes;
};

class GuestModuleBuilder {
public:
    std::vector<GuestArtifact> Build(const std::filesystem::path& inputPath, const std::filesystem::path& outputPath, Domain::SysVDynamicSection& dynamic, bool windows, bool toIntel, ISyscallScanner& syscallScanner, bool lazyBinding, const std::string& runPath, const std::set<std::string>& excludedModules) const;
};

}

#endif
