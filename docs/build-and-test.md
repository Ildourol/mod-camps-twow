# Build and verification

## Discovered environment
Windows, PowerShell; MSVC 19.44.35228.0 from Visual Studio 2022 BuildTools,
Windows SDK 10.0.26100.0. No existing CMakeCache.txt was found in the initial target
tree/workspace. No Lua/luac interpreter found in PATH or inspected vcpkg/Codex roots.
No Python or Node toolchain was introduced.

Fresh build trees created beside the standalone module:
- `../build-camps`: target Tortoise source, Visual Studio 17 2022, x64, Release.
- `../build-camps-tests`: standalone protocol tests, same generator/architecture.

Absolute paths and cache details are in references/REFERENCE_SOURCES.md. CMake's
install prefix is C:/Program Files/TurtleWoW; no install target was run.

## Commands actually run
From the outer workspace, using the discovered CMake executable:

```powershell
$cmake = 'C:/vcpkg/downloads/tools/cmake-4.4.2-windows/cmake-4.4.2-windows-x86_64/bin/cmake.exe'
& $cmake -S 'tortoise-wow-extended' -B 'build-camps' -G 'Visual Studio 17 2022' -A x64 `
  -DMODULES=disabled -DMODULE_MOD_CAMPS_TWOW=static -DBUILD_PLAYERBOTS=OFF `
  -DBUILD_ELUNA=OFF -DENABLE_SOAP=OFF -DUSE_LIBCURL=OFF `
  -DCMAKE_TOOLCHAIN_FILE=C:/vcpkg/scripts/buildsystems/vcpkg.cmake -DENABLE_LTO=OFF
& $cmake --build 'build-camps' --config Release --target mangosd --parallel 8
& $cmake -S 'mod -camps-twow/tests' -B 'build-camps-tests' -G 'Visual Studio 17 2022' -A x64
& $cmake --build 'build-camps-tests' --config Release
& 'C:/vcpkg/downloads/tools/cmake-4.4.2-windows/cmake-4.4.2-windows-x86_64/bin/ctest.exe' `
  --test-dir 'build-camps-tests' -C Release --output-on-failure
& 'mod -camps-twow/tools/verify.ps1' -CorePath 'tortoise-wow-extended'
```

The source integration is a directory junction from core/modules/mod-camps-twow
to the existing standalone directory. The outer checkout was not renamed. No core
CMake/source edit or custom module CMake script was required.

## Results
- Discovery: `mod-camps-twow: static (MODULE_MOD_CAMPS_TWOW=static)` in CMake output;
  generated ModulesLoader declares/calls Addmod_camps_twowScripts.
- Initial compile found one task error: Safe helper visibility across translation
  units. Converted to Manager member; subsequent source builds passed.
- All module C++ sources compile, modules.lib builds, **mangosd.exe links**.
- Protocol executable: **10042 checks passed**, plus **10000 malformed fuzz inputs**.
  CTest: 1/1 passed. Checks cover overflow, strict decimal ranges, version, framing,
  escapes, arity bounds, oversize payloads and randomized printable roundtrips.
- Static verification: TOC/load order, SavedVariables, 11 config keys, 22 addon
  operations, protocol identity, canonical loader, forbidden API/stale marker scans.
- Addon Lua execution: not performed; no compatible interpreter was found.
- SQL: static schema/placement review only, no server parser/application test.
- Runtime/client: not performed. No DB mutation, install, deployment or restart.

Build logs are in `../build-camps/build-release*.log`. Native dependency/core warnings
(including httplib nodiscard) are not task-caused compilation failures.

## Output
The native target chooses its runtime directory inside the core source tree:
`../tortoise-wow-extended/bin/Release/mangosd.exe`.
Static module archive: `../build-camps/modules/Release/modules.lib`.
Protocol executable: `../build-camps-tests/Release/camps_protocol_tests.exe`.
Final server SHA256 after the continent-partition audit:
`BD1DF579575610874F1338D2DFFF23BF43577E1213004A73D7DBE107E4774CB5`.
Final link log: `../build-camps/build-release-partitions.log`.

This verifies the module with BUILD_PLAYERBOTS=OFF, BUILD_ELUNA=OFF, SOAP=OFF,
MODULES globally disabled and only camps statically enabled. It is not a verification
of a bots/Eluna-enabled deployment or its production options. Preserve those options
when integrating into another existing build. Do not delete/reconfigure a valid build
merely to reuse this example.

## Repeatable acceptance progression
Inspect Git state, validate cache source/generator/config/dependencies, run static
checks and protocol tests, build/link mangosd, inspect final state, then conduct
manual-test-plan.md on an authorized development realm. Source tests do not prove
native DB/map lifecycle or stock-client UI rendering; keep those outcomes separate.
