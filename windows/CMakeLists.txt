cmake_minimum_required(VERSION 3.20)
project(Moveable LANGUAGES CXX RC)

# 버전은 저장소 루트의 VERSION 파일 하나로 관리 (예: 1.3.0)
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/../VERSION" MOVEABLE_VERSION)
string(STRIP "${MOVEABLE_VERSION}" MOVEABLE_VERSION)
string(REPLACE "." "," MOVEABLE_VERSION_COMMA "${MOVEABLE_VERSION}")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# CRT 를 정적으로 링크 → Visual C++ 재배포 패키지 없이 exe 하나로 실행
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

add_executable(Moveable WIN32 moveable.cpp moveable.rc)
target_compile_definitions(Moveable PRIVATE
  UNICODE _UNICODE
  MOVEABLE_VERSION_STR="${MOVEABLE_VERSION}"
  MOVEABLE_VERSION_COMMA=${MOVEABLE_VERSION_COMMA},0)
if(MSVC)
  target_compile_options(Moveable PRIVATE $<$<COMPILE_LANGUAGE:CXX>:/utf-8 /W4 /permissive->)
endif()
target_link_libraries(Moveable PRIVATE dwmapi)
