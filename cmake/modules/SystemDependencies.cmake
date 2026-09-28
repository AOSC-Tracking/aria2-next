find_package(Threads REQUIRED)
find_package(Boost REQUIRED)
find_package(ZLIB REQUIRED)
find_package(EXPAT REQUIRED)
find_package(SQLite3 REQUIRED)
find_package(OpenSSL ${ARIA2_MIN_OPENSSL_VERSION} REQUIRED
  COMPONENTS Crypto SSL)
find_package(CURL REQUIRED)

if(NOT TARGET ZLIB::ZLIB)
  message(FATAL_ERROR "System zlib package must provide the ZLIB::ZLIB target")
endif()
if(NOT TARGET EXPAT::EXPAT)
  message(FATAL_ERROR "System Expat package must provide the EXPAT::EXPAT target")
endif()
if(TARGET SQLite3::SQLite3)
  set(ARIA2_SYSTEM_SQLITE_TARGET SQLite3::SQLite3)
elseif(TARGET SQLite::SQLite3)
  set(ARIA2_SYSTEM_SQLITE_TARGET SQLite::SQLite3)
else()
  message(FATAL_ERROR "System SQLite3 package must provide a SQLite3 target")
endif()
if(NOT TARGET CURL::libcurl)
  message(FATAL_ERROR "System curl package must provide the CURL::libcurl target")
endif()

add_library(aria2::zlib ALIAS ZLIB::ZLIB)
add_library(aria2::expat ALIAS EXPAT::EXPAT)
add_library(aria2::sqlite ALIAS ${ARIA2_SYSTEM_SQLITE_TARGET})
set(ARIA2_BOOST_ROOT "${Boost_INCLUDE_DIRS}")
set(ARIA2_LIBTORRENT_INCLUDE_DIR
  "${CMAKE_SOURCE_DIR}/third_party/libtorrent/include")
set(ARIA2_SYSTEM_DEPENDENCIES ON)
set(ARIA2_DEPENDENCY_LINKAGE SHARED)

# Keep the media stack project-owned: GPAC is not consistently packaged with
# development files, and the engine relies on the patched vendored sources.
include(ExternalProject)
include(ProcessorCount)
find_program(ARIA2_MAKE_EXECUTABLE make REQUIRED)
find_program(ARIA2_POSIX_SHELL NAMES bash sh REQUIRED)
ProcessorCount(ARIA2_BUILD_JOBS)
if(NOT ARIA2_BUILD_JOBS)
  set(ARIA2_BUILD_JOBS 2)
endif()
set(ARIA2_VENDOR_ROOT "${CMAKE_SOURCE_DIR}/third_party")
set(ARIA2_DEPENDENCY_PREFIX "${CMAKE_BINARY_DIR}/vendored-media")
file(MAKE_DIRECTORY "${ARIA2_DEPENDENCY_PREFIX}/include")
include(${CMAKE_SOURCE_DIR}/cmake/superbuild/Media.cmake)

foreach(component gpac avformat avcodec swresample avutil)
  if(component STREQUAL "gpac")
    set(library_name gpac_static)
  else()
    set(library_name "${component}")
  endif()
  add_library(aria2::${component} STATIC IMPORTED GLOBAL)
  set_target_properties(aria2::${component} PROPERTIES
    IMPORTED_LOCATION "${ARIA2_DEPENDENCY_PREFIX}/lib/lib${library_name}.a"
    INTERFACE_INCLUDE_DIRECTORIES "${ARIA2_DEPENDENCY_PREFIX}/include")
endforeach()
set_property(TARGET aria2::gpac PROPERTY INTERFACE_COMPILE_DEFINITIONS
  GPAC_ALLOW_UNSAFE_STRFUNC)
foreach(component avformat avcodec swresample avutil)
  set_property(TARGET aria2::${component} PROPERTY INTERFACE_COMPILE_DEFINITIONS
    "$<$<COMPILE_LANGUAGE:CXX>:__STDC_CONSTANT_MACROS>")
endforeach()


if(ARIA2_ENABLE_BITTORRENT)
  # Use the patched vendored libtorrent while common dependencies remain system-provided.
  set(_aria2_saved_build_shared_libs "${BUILD_SHARED_LIBS}")
  set(BUILD_SHARED_LIBS OFF)
  set(build_tests OFF)
  set(build_examples OFF)
  set(build_tools OFF)
  set(python-bindings OFF)
  set(deprecated-functions OFF)
  set(extensions ON)
  set(mutable-torrents ON)
  set(streaming ON)
  set(i2p OFF)
  set(webtorrent OFF)
  set(logging ON)
  set(encryption ON)
  set(dht ON)
  add_subdirectory(
    "${CMAKE_SOURCE_DIR}/third_party/libtorrent"
    "${CMAKE_BINARY_DIR}/third_party/libtorrent"
    EXCLUDE_FROM_ALL)
  add_library(LibtorrentRasterbar::torrent-rasterbar ALIAS torrent-rasterbar)
  set(BUILD_SHARED_LIBS "${_aria2_saved_build_shared_libs}")
endif()
