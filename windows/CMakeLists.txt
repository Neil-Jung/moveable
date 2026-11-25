cmake_minimum_required(VERSION 3.20)
project(Moveable LANGUAGES CXX RC)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# CRT 를 정적으로 링크 → Visual C++ 재배포 패키지 없이 exe 하나로 실행
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

add_executable(Moveable WIN32 moveable.cpp moveable.rc)
target_compile_definitions(Moveable PRIVATE UNICODE _UNICODE)
if(MSVC)
  target_compile_options(Moveable PRIVATE /utf-8 /W4 /permissive-)
endif()
target_link_libraries(Moveable PRIVATE dwmapi)
